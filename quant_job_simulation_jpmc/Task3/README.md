***Credit Risk Analysis***

Problem Statement:
The risk manager has collected data on the loan borrowers. The data is in tabular format, with each row providing details of the borrower, including their income, total loans outstanding, and a few other metrics. There is also a column indicating if the borrower has previously defaulted on a loan. You must use this data to build a model that, given details for any loan described above, will predict the probability that the borrower will default (also known as PD: the probability of default). Use the provided data to train a function that will estimate the probability of default for a borrower. Assuming a recovery rate of 10%, this can be used to give the expected loss on a loan.
You should produce a function that can take in the properties of a loan and output the expected loss.
You can explore any technique ranging from a simple regression or a decision tree to something more advanced. You can also use multiple methods and provide a comparative analysis.

What I Did:

I performed **credit risk modeling** to estimate the **Probability of Default (PD)** and **Expected Loss (EL)** for individual borrowers.  

**Key steps:**
- Preprocessed the loan dataset and created derived features such as `payment-to-income` and `debt-to-income` ratios.
- Trained multiple models: **Logistic Regression, Random Forest, and XGBoost**.
- Calibrated all models using **isotonic regression** for reliable probability estimates.
- Evaluated model performance using **AUC, Brier score, ROC curves, and reliability plots**.
- Implemented an **Expected Loss function** that combined predicted PDs, loan exposure, and recovery rates to compute potential financial losses.

**Skills gained:** Feature engineering, supervised learning, probability calibration, model evaluation, financial risk assessment.
