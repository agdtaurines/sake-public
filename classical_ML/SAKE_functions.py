#====================================================================================#
### This python file contains all the functions needed for SAKE_run-analysis.ipynb ###
#====================================================================================#

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Amalgamate the features of all subjects for a pipeline into a full raw feature matrix

def raw_fx(csv, pipeline, outdir, subinfo, wd):
    import pandas as pd
    import os
    import glob
    
    print(f"Amalgamating {pipeline} features into a full raw matrix...", end='')
    # Extract column headers
    csv_pattern = os.path.join(outdir, '**', csv)  # Match csv file in any subdirectory
    csv_path = None
    for path in glob.iglob(csv_pattern, recursive=True):
        csv_path = path  # Capture the first match
        break  # Stop searching after the first match
    if csv_path:  # Check if a CSV was found
        df = pd.read_csv(csv_path)
        headers = list(df.columns)
        headers.insert(0, 'PTID')  # Insert "PTID" as the first column header
        fx = pd.DataFrame(columns=headers)  # Create a new blank DataFrame with the extracted column headers
    else:
        print(f"No {csv} file found in the directory.")
        return  # Exit the function if no file is found

    # Iterate over the subjects and amalgamate the features, adding PTID in column 1
    vals = []
    for idx in range(subinfo.shape[0]):
        sub = subinfo.iloc[idx].loc["PTID"]
        csvdir = os.path.join(outdir, sub, subinfo.iloc[idx].loc["T1_path"].split('/')[-2], pipeline, csv)
        if os.path.isfile(csvdir):
            # Amalgamate - and add PTID as first column
            subfx = pd.read_csv(csvdir)
            subfx.insert(0, "PTID", sub)
            if not subfx.empty and not subfx.isna().all().all():
                vals.append(subfx)            
    if vals:
        fx = pd.concat(vals, ignore_index=True)
    # Save the final DataFrame to a CSV file
    fx.to_csv(os.path.join(wd, pipeline, 'raw_fx.csv'), index=False)
    print("...done!")
          
          
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------          
# Run ML training and testing

def run_ML(working_dir, pipeline, model, featfilter="nofilt", seed=42):
    import os
    import numpy as np
    import pandas as pd    
    from sklearn.base import clone
    from sklearn.utils import resample
    from sklearn.feature_selection import RFECV, SelectFromModel
    from sklearn.preprocessing import StandardScaler
    from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
    from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, confusion_matrix, roc_curve
    from sklearn.linear_model import LogisticRegression
    from skopt import BayesSearchCV
    from skopt.space import Real, Categorical, Integer
    from collections import Counter
    import shap
    import pymrmr
    import seaborn as sns
    import matplotlib.pyplot as plt
    import joblib
    import time
    
    t0 = time.time()
    print(f"~~~Running {model} for pipeline {pipeline}!~~~")
    wd = working_dir
    outdir = os.path.join(wd, pipeline, str(seed), model, featfilter)

    if not os.path.isdir(outdir): # make results directory
        os.makedirs(outdir)
    
    fx = pd.read_csv(os.path.join(wd, pipeline, "fx.csv"))
    print("Total number of subjects      :", fx.shape[0])

    # Remove MCI
    fx = fx.loc[fx['DIAGNOSIS'] != 2]
    fx['DIAGNOSIS'] = fx['DIAGNOSIS'].replace({1: 0, 3: 1})
    print("Number of AD and CN subjects  :", fx.shape[0])
          
    # Remove columns with any missing values
    print("Columns with missing values   :", fx.columns[fx.isna().any()].tolist())
    fx = fx.dropna(axis=1)

    # Extract features and targets
    fx['stratify_key'] = (fx['PTGENDER'].astype(str) + "_" + fx['DIAGNOSIS'].astype(str))
    train_df, test_df = train_test_split(fx, test_size=0.15, stratify=fx['stratify_key'], random_state=seed)
    train_df = train_df.drop('stratify_key', axis=1)
    test_df = test_df.drop('stratify_key', axis=1)
    
    X_train = train_df.iloc[:, 7:]
    y_train = train_df['DIAGNOSIS']
    X_test = test_df.iloc[:, 7:]
    y_test = test_df['DIAGNOSIS']
    
    feature_names = X_train.columns
    test_idx = y_test.index #keep note of test set indices

    # Standardise the features
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)
    print("Number of Training subjects   :", len(X_train))
    print("Number of Test subjects       :", len(X_test))

    scoring = 'roc_auc' #"f1"
    
    # ~~~ Set model hyperparameter grids ~~~
    if model == "SVM":
        from sklearn.svm import SVC
        param_grid = {
            'C': Real(0.001, 1, prior='uniform'),
            'gamma': Real(1e-4, 10, prior='log-uniform'),
            'degree': Integer(2, 5),
            'kernel': Categorical(['linear', 'rbf', 'poly', 'sigmoid'])}
        mdl = SVC(probability=True, random_state=seed)
    elif model == "RF":
        from sklearn.ensemble import RandomForestClassifier
        param_grid = {
            'n_estimators': Integer(50, 200),
            'max_depth': Integer(2, 30),
            'min_samples_split': Integer(2, 10),
            'min_samples_leaf': Integer(1, 4)}
        mdl = RandomForestClassifier(random_state=seed)
    elif model == "LR":
        from sklearn.linear_model import LogisticRegression
        param_grid = {
            'C': Real(0.001, 10, prior='log-uniform'),
            'solver': Categorical(['lbfgs', 'liblinear', 'sag']),
            'penalty': Categorical(['l2'])}
        mdl = LogisticRegression(random_state=seed, max_iter=1000)
    elif model == "NB":
        from sklearn.naive_bayes import GaussianNB
        param_grid = {'var_smoothing': Real(1e-11, 1e-5, prior='log-uniform')}
        mdl = GaussianNB()
    elif model == "kNN":
        from sklearn.neighbors import KNeighborsClassifier
        param_grid = {
            'n_neighbors': Integer(5, 15),
            'weights': Categorical(['uniform', 'distance']),
            'metric': Categorical(['euclidean', 'manhattan'])}
        mdl = KNeighborsClassifier()
    elif model == "XGB":
        from xgboost import XGBClassifier
        param_grid = {
            'n_estimators': Integer(50, 200),
            'learning_rate': Real(0.01, 0.5),
            'max_depth': Integer(2, 30),
            'subsample': Real(0.1, 1.0),
            'colsample_bytree': Real(0.1, 1.0)}
        mdl = XGBClassifier(objective='binary:logistic', random_state=seed)
    elif model == "MLP":
        from sklearn.neural_network import MLPClassifier
        param_grid = {
            'hidden_layer_sizes': Integer(10, 130),
            'activation': Categorical(['identity', 'logistic', 'tanh', 'relu']),
            'solver': Categorical(['adam']),
            'alpha': Real(1e-5, 1e-1, prior='log-uniform')}
        mdl = MLPClassifier(random_state=seed, early_stopping=True, n_iter_no_change=10, validation_fraction=0.1, max_iter=2000)

    # ~~~ Feature selection using MRMR ~~~
    if featfilter == "mrmr":
        print("~ Running MRMR feature selection! ~\n")
        # Feature filtering using MRMR
        print("Filtering features using MRMR algorithm...\n")
        X_train_df = pd.DataFrame(X_train, columns=feature_names)
        X_test_df  = pd.DataFrame(X_test,  columns=feature_names)
        df_train   = pd.concat([y_train.reset_index(drop=True), X_train_df.reset_index(drop=True)], axis=1)
        features_filtered = np.array(pymrmr.mRMR(df_train, 'MIQ', 50))
    
        # Hyperparameter tuning for stepwise feature elimination
        print("\nTuning hyperparameters for feature elimination...\n")
        opt = BayesSearchCV(estimator=mdl, search_spaces=param_grid, n_iter=50, scoring=scoring, cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=seed), random_state=seed, n_jobs=-1)
        opt.fit(X_train_df[features_filtered], y_train)
        best_mdl = opt.best_estimator_
        print(f"Best hyperparameters (for feature elimination): {opt.best_params_}")
    
        # Stepwise backward feature elimination (using MRMR feature importance values)
        print("Performing stepwise feature elimination...\n")
        num_features, mean_performance_scores, std_performance_scores = [], [], []
        feature_subsets = list(features_filtered)

        for i in range(len(feature_subsets), 0, -1):
            performance_scores = cross_val_score(best_mdl, X_train_df[feature_subsets], y_train, cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=seed), scoring=scoring, n_jobs=-1)
            num_features.append(i)
            mean_performance_scores.append(np.mean(performance_scores))
            std_performance_scores.append(np.std(performance_scores))
            feature_subsets.remove(feature_subsets[-1]) # Remove last feature in importance order

        best_idx          = np.argmax(mean_performance_scores)
        best_num_features = num_features[best_idx]
        best_features     = features_filtered[:best_num_features]
        print(f"Number of features post-MRMR-RFECV: {best_num_features}")

        plt.figure(figsize=(8, 5))
        plt.plot(num_features, mean_performance_scores, marker='x', linestyle='-', color='k')
        plt.fill_between(num_features, np.array(mean_performance_scores) - np.array(std_performance_scores), np.array(mean_performance_scores) + np.array(std_performance_scores), color='r', alpha=0.2, label="±1 std")
        plt.xlabel("Number of Features")
        plt.xlim(0, 51)
        plt.ylabel(f"Mean {scoring} score")
        plt.ylim(0.6, 1.0)
        plt.title("Feature Elimination using MRMR Performance (±1 std)")
        plt.grid()
        plt.tight_layout()
        plt.savefig(os.path.join(outdir, f"{model}_{pipeline}_MRMRFeatElim.jpg"), dpi=300)
        plt.close()

        selected_features = list(best_features)
        X_train_selected = X_train_df[best_features]
        X_test_selected = X_test_df[best_features]
    
    # ~~~ Feature filtering using L1 ~~~
    elif featfilter == "l1":
        print("~ Running L1 feature selection! ~")
        l1_param_grid = {
            'C': Real(0.001, 10, prior='log-uniform'),
            'solver': Categorical(['liblinear']),
            'penalty': Categorical(['l1'])}
        l1 = BayesSearchCV(estimator=LogisticRegression(random_state=seed, max_iter=1000), 
                           search_spaces=l1_param_grid, n_iter=50, scoring=scoring, 
                           cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=seed), random_state=seed, n_jobs=-1)
        l1.fit(X_train, y_train)
        selector = SelectFromModel(l1.best_estimator_, prefit=True)
        X_train_selected = selector.transform(X_train)
        X_test_selected = selector.transform(X_test)
        selected_features = list(np.array(feature_names)[selector.get_support()])
        print("Number of Features post-L1    :", len(selected_features))
        print("Selected Feature Names        :", selected_features)

    # ~~~ No feature selection ~~~
    else:
        print("~ No feature selection! ~")
        X_train_selected = X_train
        X_test_selected = X_test
        selected_features = list(feature_names)
    
    # ~~~ Hyperparameter tuning & classification threshold identification ~~~
    print("Tuning hyperparameters and finding classification threshold for final model...")
    X_train_arr      = np.array(X_train_selected)
    y_train_arr      = np.array(y_train)
    
    skf              = StratifiedKFold(n_splits=5, shuffle=True, random_state=seed)
    fold_best_params = []
    fold_val_perform = []
    oof_probs        = np.zeros(len(y_train_arr))
    oof_labels       = np.zeros(len(y_train_arr))    

    for fold, (fold_train_idx, fold_val_idx) in enumerate(skf.split(X_train_arr, y_train_arr)):
        print(f"--- Fold {fold + 1}/5 ---")
        X_fold_train = X_train_arr[fold_train_idx]
        y_fold_train = y_train_arr[fold_train_idx]
        X_fold_val   = X_train_arr[fold_val_idx]
        y_fold_val   = y_train_arr[fold_val_idx]

        # Hyperparameter tuning on this fold's training data
        opt = BayesSearchCV(estimator=clone(mdl), search_spaces=param_grid, n_iter=50, scoring=scoring, cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=seed),  random_state=seed, n_jobs=-1)
        opt.fit(X_fold_train, y_fold_train)
        fold_best_params.append(opt.best_params_)

        # Accumulate out-of-fold predicted probabilities for pooled threshold
        fold_mdl = opt.best_estimator_
        oof_probs[fold_val_idx]  = fold_mdl.predict_proba(X_fold_val)[:, 1]
        oof_labels[fold_val_idx] = y_fold_val
        fold_val_perform.append(roc_auc_score(y_fold_val, oof_probs[fold_val_idx]))
        print(f"Best params : {opt.best_params_}")
        print(f"Val {scoring}: {fold_val_perform[-1]:.4f}")

    # Pooled threshold: Youden's Index on all out-of-fold predictions
    fpr_oof, tpr_oof, thresholds_oof = roc_curve(oof_labels, oof_probs)
    youden_idx = np.argmax(tpr_oof - fpr_oof)
    optimal_threshold = thresholds_oof[youden_idx]
    print(f"\nPooled OOF {scoring}: {roc_auc_score(oof_labels, oof_probs):.4f}")
    print(f"Optimal threshold: {optimal_threshold:.4f}")

    # Find most frequent hyperparameter across folds
    best_params = {}
    for key in param_grid.keys():
        values = [p[key] for p in fold_best_params]
        space  = param_grid[key]

        if isinstance(space, Categorical):
            best_params[key] = Counter(values).most_common(1)[0][0] # Most frequent value for categorical parameters
        elif isinstance(space, Real):
            best_params[key] = float(np.median(values)) # Median for continuous parameters
        elif isinstance(space, Integer):
            best_params[key] = int(np.round(np.median(values))) # Median rounded to nearest integer for integer parameters

    print(f"\nAggregated hyperparameters across folds: {best_params}")

    # Log per-fold values
    for key in param_grid.keys():
        values = [p[key] for p in fold_best_params]
        print(f"  {key}: {values} → {best_params[key]}")

    # Save fold-level diagnostics and select hyperparameters
    fold_diagnostics = pd.DataFrame({
        'fold'          : list(range(1, 6)),
        f"val_{scoring}": fold_val_perform,
        'params'        : [str(p) for p in fold_best_params]})
    fold_diagnostics.to_csv(os.path.join(outdir, f"{model}_{pipeline}_fold_optimalparams.csv"), index=False)

    # ~~~ Fit final model on full training data using optimal theshold and hyperparameters ~~~
    print("Fitting final model on full training set...")
    mdl = clone(mdl)
    mdl.set_params(**best_params)
    mdl.fit(X_train_selected, y_train)

    # Save individual predictions
    y_test_prob = mdl.predict_proba(X_test_selected)[:, 1]
    y_test_pred = (y_test_prob >= optimal_threshold).astype(int) #Applying optimal threshold

    tn, fp, fn, tp = confusion_matrix(y_test, y_test_pred).ravel()
    performance = {
        'accuracy'         : accuracy_score(y_test, y_test_pred),
        'precision'        : precision_score(y_test, y_test_pred, average='macro'),
        'sensitivity'      : recall_score(y_test, y_test_pred, average='macro'),
        'specificity'      : tn / (tn + fp),
        'f1'               : f1_score(y_test, y_test_pred, average='macro'),
        'auc_roc'          : roc_auc_score(y_test, y_test_prob),
        'optimal_threshold': optimal_threshold}
    
    performance_df = pd.DataFrame([performance])
    performance_df.to_csv(os.path.join(outdir, f"{model}_{pipeline}_performance_df.csv"), index=False)

    test_pred_demog = fx.loc[test_idx, fx.columns[:7]].copy()
    test_pred_demog['PREDICTIONS']  = pd.Series(y_test_pred, index=test_pred_demog.index).astype(int)
    test_pred_demog['prob_class_1'] = pd.Series(y_test_prob, index=test_pred_demog.index)
    test_pred_demog['threshold']    = optimal_threshold
    test_pred_demog.to_csv(os.path.join(outdir, f"{model}_{pipeline}_predictions_df.csv"), index=False)

    # ~~~ Plot confusion matrix ~~~
    print("Plotting confusion matrix...")
    labels = ['CN', 'AD']
    conf_matrix = confusion_matrix(y_test, y_test_pred)
    plt.figure(figsize=(6, 5))
    sns.heatmap(conf_matrix, annot=True, fmt='d', cmap='Blues', xticklabels=labels, yticklabels=labels)
    plt.xlabel('Predicted Class')
    plt.ylabel('True Class')
    plt.title(f"{model} Confusion Matrix (preprocessing by {pipeline})")
    plt.tight_layout()
    plt.savefig(os.path.join(outdir, f"{model}_{pipeline}_confmat.jpg"), dpi=300)
    plt.close()
    pd.DataFrame(conf_matrix).to_csv(os.path.join(outdir, f"{model}_{pipeline}_confmat.csv"), index=False)

    # ~~~ Generate, plot and save SHAP values ~~~
    print("Generating and saving SHAP values...")
    # Compute SHAP values
    if model == "LR":
        explainer  = shap.LinearExplainer(mdl, X_train_selected)
        shap_vals  = np.array(explainer.shap_values(X_test_selected))

    elif model in ("RF", "XGB"):
        explainer      = shap.TreeExplainer(mdl)
        shap_explained = explainer(X_test_selected)
        shap_vals = (np.array(shap_explained.values[:, :, 1]) if model == "RF" else np.array(shap_explained.values)) # RF returns shape (n_samples, n_features, n_classes) - take class 1. XGB returns shape (n_samples, n_features) - use directly.

    else:
        background_data = shap.sample(X_train_selected, 100)
        explainer = shap.KernelExplainer(lambda X: mdl.predict_proba(X)[:, 1], background_data)
        shap_vals = np.array(explainer.shap_values(X_test_selected))

    # Plot and save
    shap.summary_plot(shap_vals, X_test_selected, feature_names=selected_features, show=False, plot_size=0.3, max_display=10)
    plt.title(f"{model} SHAP values (preprocessing by {pipeline})")
    plt.tight_layout()
    plt.savefig(os.path.join(outdir, f"{model}_{pipeline}_shap.jpg"), dpi=300, bbox_inches='tight')
    plt.close()
          
    shap_df = pd.DataFrame(shap_vals, columns=selected_features)
    shap_df['PTID']        = fx.loc[test_idx, 'PTID'].values
    shap_df['true_label']  = y_test.values
    shap_df['prediction']  = y_test_pred
    shap_df = shap_df[['PTID', 'true_label', 'prediction'] + list(selected_features)]
    shap_df.to_csv(os.path.join(outdir, f"{model}_{pipeline}_shap_values.csv"), index=False)

    # Save trained model and test idx
    print("Saving model and test_idx...")
    joblib.dump(mdl, os.path.join(outdir, f"{model}_trained.joblib"))
    pd.Series(test_idx).to_csv(os.path.join(outdir, "test_idx.csv"), index=False, header=False)

    print("Done!")
    t1 = time.time()
    t_total = t1-t0
    print("Run time (s):", t_total)
    
    with open(os.path.join(outdir, "Runtime.txt"), "w") as t_file:
        t_file.write("%s" % t_total)
    return