import os
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import random_split, DataLoader
import torchvision
import torchio as tio
import pytorch_lightning as pl
from pytorch_lightning.loggers import WandbLogger
from pytorch_lightning.callbacks import ModelCheckpoint, Timer, DeviceStatsMonitor
import wandb
from tqdm import tqdm
from argparse import ArgumentParser
import torchmetrics

#os.environ["CUDA_VISIBLE_DEVICES"] = "1"

image_size = (109, 109, 109) #original image shape is (182, 218, 182). 218/2=109
spacing = (2, 2, 2) #Using larger voxels for efficiency
num_classes = 2
batch_size = 16 #64
epochs = 100
val_ratio = 0.15
num_workers = 8 #4
learning_rate = 0.001 #8e-4
weight_decay = 1e-4

class BrainDataModule(pl.LightningDataModule):
    def __init__(self, image_size, spacing, batch_size, val_ratio, num_workers, csv_train_img=None, csv_test_img=None, seed=42):
        super().__init__()
        self.seed = seed
        self.csv_train_img = csv_train_img
        self.csv_test_img = csv_test_img
        self.image_size = image_size
        self.spacing = spacing
        self.batch_size = batch_size
        self.val_ratio = val_ratio
        self.num_workers = num_workers
        self.subjects_train = None
        self.subjects_test = None
        self.preprocess = None
        self.transform = None
        self.train_set = None
        self.val_set = None
        self.test_set = None

    def load_subjects(self, csv_img):
        img_data = pd.read_csv(csv_img)
        #img_data = img_data[0:100] #########TO TEST
        subjects = []
        for _, row in tqdm(img_data.iterrows(), total=len(img_data), desc='Loading Data'):
            subject = tio.Subject(
                image=tio.ScalarImage(row["T1_path"]),
                label=torch.tensor(int(row["DIAGNOSIS"]), dtype=torch.long),
                ptid=row["PTID"])
            subjects.append(subject)
        return subjects

    def preprocessing_transform(self):
        transform = tio.Compose([
            tio.ZNormalization(masking_method=lambda x: (x.data != 0).bool()),
            tio.Resample(self.spacing),
            tio.CropOrPad(self.image_size)])
        return transform

    def augmentation_transform(self):
        transform = tio.Compose([
            tio.RandomGamma(p=0.5, log_gamma=(-0.1,0.1)),
            tio.RandomNoise(p=0.5, std=0.1),
            tio.RandomMotion(p=0.5),
            tio.RandomBiasField(p=0.5, coefficients=0.1),
            tio.RandomAffine(p=0.5, scales=0.01, degrees=2, default_pad_value=0),
            tio.RandomElasticDeformation(p=0.5, num_control_points=7, max_displacement=4, locked_borders=2)])
        return transform
    
    def postprocessing_transform(self):
        transform = tio.Compose([
            tio.Mask(masking_method=lambda x: (x.data != 0).bool())])
        return transform

    def setup(self, stage=None):
        preprocess = self.preprocessing_transform()
        augment = self.augmentation_transform()
        postprocess = self.postprocessing_transform()
        train_transform = tio.Compose([preprocess, augment, postprocess])
        test_transform = tio.Compose([preprocess, postprocess])
        
        if self.csv_train_img is not None:
            # Create Train/Val sets
            self.subjects_train = self.load_subjects(self.csv_train_img)
            num_subs = len(self.subjects_train)
            num_val_subs = int(round(num_subs * self.val_ratio))
            num_train_subs = num_subs - num_val_subs

            splits = num_train_subs, num_val_subs
            train_subjects, val_subjects = random_split(self.subjects_train, splits, generator=torch.Generator().manual_seed(self.seed))
            
            self.train_set = tio.SubjectsDataset(train_subjects, transform=train_transform)
            self.val_set = tio.SubjectsDataset(val_subjects, transform=test_transform)
            print('Nb train: ', len(self.train_set))
            print('Nb val:   ', len(self.val_set))
        
        if self.csv_test_img is not None:
            # Create Test set
            self.subjects_test = self.load_subjects(self.csv_test_img)
            self.test_set = tio.SubjectsDataset(self.subjects_test, transform=test_transform)
            print('Nb test:  ', len(self.test_set))

    def train_dataloader(self):
        if self.train_set is not None:
            return DataLoader(self.train_set, self.batch_size, num_workers=self.num_workers, shuffle=True, drop_last=True, pin_memory=True, persistent_workers=True)
        return None

    def val_dataloader(self):
        if self.val_set is not None:
            return DataLoader(self.val_set, self.batch_size, num_workers=self.num_workers, pin_memory=True, persistent_workers=True)
        return None

    def test_dataloader(self):
        if self.test_set is not None:
            return DataLoader(self.test_set, self.batch_size, num_workers=self.num_workers, pin_memory=True, persistent_workers=True)
        return None
    
class NN3DClassifier(pl.LightningModule):
    def __init__(self, model_name, learning_rate=0.001, weight_decay=1e-4, in_channels=1, num_classes=2, image_size=(109, 109, 109)):
        super().__init__()
        self.save_hyperparameters()
        
        if model_name == "resnet18":
            from models.resnet3d import resnet18_3d
            self.model = resnet18_3d(in_channels=1, num_classes=num_classes)
        elif model_name == "resnet50":
            from models.resnet3d import resnet50_3d
            self.model = resnet50_3d(in_channels=1, num_classes=num_classes)
        elif model_name == "lenet5":
            from models.lenet3d import lenet5_3d
            self.model = lenet5_3d(in_channels=1, num_classes=num_classes, image_size=image_size)
        elif model_name == "densenet121":
            import monai
            self.model = monai.networks.nets.DenseNet121(spatial_dims=3, in_channels=1, out_channels=num_classes)
            
        # Metrics
        self.train_acc = torchmetrics.classification.Accuracy(task="binary")
        self.val_acc = torchmetrics.classification.Accuracy(task="binary")
        self.test_acc = torchmetrics.classification.Accuracy(task="binary")

        self.train_auroc = torchmetrics.classification.AUROC(task="binary")
        self.val_auroc = torchmetrics.classification.AUROC(task="binary")
        self.test_auroc = torchmetrics.classification.AUROC(task="binary")

    def forward(self, x):
        return self.model(x)

    def configure_optimizers(self):
        return torch.optim.Adam(
            self.parameters(), 
            lr=self.hparams.learning_rate, 
            weight_decay=self.hparams.weight_decay)

    def unpack_batch(self, batch):
        return batch['image'][tio.DATA], batch['label'], batch['ptid']

    def process_batch(self, batch):
        img, targets, _ = self.unpack_batch(batch)
        targets = targets.view(-1)
        
        logits = self.forward(img)
        loss = F.cross_entropy(logits, targets)
        
        probs = F.softmax(logits, dim=1)[:, 1]
        preds = torch.argmax(logits, dim=1)
        
        bsize = img.shape[0]
        return loss, preds, probs, targets, bsize

    def training_step(self, batch, batch_idx):
        loss, preds, probs, targets, bsize = self.process_batch(batch)
        
        acc = self.train_acc(preds, targets)
        auroc = self.train_auroc(probs, targets)
        
        self.log('train_loss', loss, batch_size=bsize)
        self.log('train_acc', acc, prog_bar=True, batch_size=bsize)
        self.log('train_auroc', auroc, prog_bar=True, batch_size=bsize)
        
        # Visualise first subject brain slices (sanity check pre-processing
        if self.current_epoch == 0 and batch_idx == 0:
            img = batch['image'][tio.DATA][0]
            img = img[0]
            D, H, W = img.shape

            # Take middle slices in all three orientations
            a = img[D//2, :, :]
            b = img[:, H//2, :]
            c = img[:, :, W//2]

            # Add channel dimension for torchvision.utils.make_grid
            slices = torch.stack([a, b, c], dim=0).unsqueeze(1)
            grid = torchvision.utils.make_grid(slices, nrow=3, normalize=True)
            self.logger.experiment.log({"middle_slices": wandb.Image(grid), "step": self.global_step})
        
        return loss

    def validation_step(self, batch, batch_idx):
        loss, preds, probs, targets, bsize = self.process_batch(batch)
        
        acc = self.val_acc(preds, targets)
        auroc = self.val_auroc(probs, targets)

        self.log('val_loss', loss, batch_size=bsize)
        self.log('val_acc', acc, prog_bar=True, batch_size=bsize)
        self.log('val_auroc', auroc, prog_bar=True, batch_size=bsize)
        return loss

    def on_test_start(self):
        self.test_ptids, self.test_targets, self.test_preds, self.test_probs = [], [], [], []

    def test_step(self, batch, batch_idx):
        loss, preds, probs, targets, bsize = self.process_batch(batch)

        acc = self.test_acc(preds, targets)
        auroc = self.test_auroc(probs, targets)

        self.log('test_loss', loss, batch_size=bsize)
        self.log('test_acc', acc, prog_bar=True, batch_size=bsize)
        self.log('test_auroc', auroc, prog_bar=True, batch_size=bsize)

        self.test_ptids.extend(batch['ptid'])
        self.test_targets.append(targets.detach().cpu())        
        self.test_preds.append(preds.detach().cpu())
        self.test_probs.append(probs.detach().cpu())
        return loss

    def on_test_end(self):
        self.test_targets = torch.cat(self.test_targets).numpy()
        self.test_preds = torch.cat(self.test_preds).numpy()
        self.test_probs = torch.cat(self.test_probs, dim=0).numpy()

def main(args):
    seed = args.seed
    model_name = args.model_name
    outdir = args.outdir
    trainpath = args.trainpath
    testpath = args.testpath
    
    pl.seed_everything(seed, workers=True)
    full_outdir = os.path.join(outdir, f"output_{model_name}")
    os.makedirs(full_outdir, exist_ok=True)
    
    print("CUDA available:", torch.cuda.is_available())
    print("Device count  :", torch.cuda.device_count())
    print("Device name   :", torch.cuda.get_device_name())
    print(f"Model: {model_name} \nSeed: {seed} \nBatch Size: {batch_size} \nLearning Rate: {learning_rate} \nWeight Decay: {weight_decay}")
    
    if args.trainpath is None:
        raise ValueError("Running this script on the command line requires --trainpath! For separate testing, import the functions into a notebook and run it from there.")
    
    # Data
    data = BrainDataModule(
        csv_train_img=trainpath,
        csv_test_img=testpath,
        image_size=image_size,
        spacing=spacing,
        batch_size=batch_size,
        val_ratio=val_ratio,
        num_workers=num_workers, 
        seed=seed)

    # Model
    model = NN3DClassifier(
        model_name=model_name, 
        learning_rate=learning_rate, 
        weight_decay=weight_decay, 
        num_classes=num_classes,
        image_size=image_size)

    # Checkpoint callback
    checkpoint_callback = pl.callbacks.ModelCheckpoint(
        dirpath=os.path.join(full_outdir, "checkpoints"),
        monitor="val_auroc",
        mode="max",
        save_top_k=1,
        filename="best_model")
    
    early_stop_callback = pl.callbacks.EarlyStopping(
        monitor="val_auroc",
        min_delta=0.0,
        patience=20,
        verbose=True,
        mode="max"
    )
    
    timer_callback = Timer(duration=None)
    device_stats_callback = DeviceStatsMonitor()

    # Logger
    wandb_logger = WandbLogger(project="SAKE", name=f"seed{seed}_{model_name}")
    wandb_logger._default_hp_metric = False

    # Trainer
    trainer = pl.Trainer(
        max_epochs=epochs,
        accelerator=args.dev,
        devices="auto",
        logger=wandb_logger,
        callbacks=[checkpoint_callback, early_stop_callback, timer_callback, device_stats_callback],
        log_every_n_steps=5)

    # Training
    print("Starting training...")
    trainer.fit(model, data)
    print(f"Training complete for {model_name}! \nBest checkpoint at: {checkpoint_callback.best_model_path}")
    print(f"Total training time (s): {timer_callback.time_elapsed('train')}")

    # Testing
    if args.testpath is not None:
        # Load best checkpoint
        best_model_path = checkpoint_callback.best_model_path
        print(f"\nLoading best model from: {best_model_path}")
        best_model = NN3DClassifier.load_from_checkpoint(
            best_model_path,
            model_name=model_name,
            learning_rate=learning_rate,
            weight_decay=weight_decay,
            num_classes=num_classes
        )

        print(f"Best validation auroc: {checkpoint_callback.best_model_score.item():.4f}")

        # Test on test set
        print("\nTESTING:")
        trainer.test(best_model, dataloaders=data.test_dataloader())

        df_test = pd.DataFrame(best_model.test_probs, columns=['prob_class_1'])
        df_test['pred'] = best_model.test_preds
        df_test['target'] = best_model.test_targets
        df_test['ptid'] = best_model.test_ptids
        cols = ['ptid'] + [c for c in df_test.columns if c != 'ptid'] #reorder
        df_test = df_test[cols]
        df_test.to_csv(os.path.join(full_outdir, "predictions_test.csv"), index=False)
        
        print(f"Total testing time (s): {timer_callback.time_elapsed('test')}")
    
if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('--dev', default='gpu')
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--model_name', type=str, required=True)
    parser.add_argument('--outdir', type=str, required=True)
    parser.add_argument('--trainpath', type=str, default=None)
    parser.add_argument('--testpath', type=str, default=None)
    args = parser.parse_args()
    main(args)