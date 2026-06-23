## Key Results & Findings

```
════════════════════════════════════════════════════════════════
                    MODEL PERFORMANCE SUMMARY
════════════════════════════════════════════════════════════════

  Target Variable:     HEART_DISEASE_STATUS (Binary: 0 = No, 1 = Yes)
  Feature Count:       19 input features
  Class Distribution:  ~50% positive / 50% negative (balanced)
  Data Source:         Snowflake (3 partitioned tables, merged at runtime)

CORRELATION WITH TARGET (Pearson)
─────────────────────────────────────────────────────────────────
  Highest:   STRESS_LEVEL        +0.021
             GENDER              +0.017
             BMI                 +0.017
             CHOLESTEROL_LEVEL   +0.015
             SMOKING             +0.014
  Lowest:    BLOOD_PRESSURE      −0.019
             LOW_HDL_CHOLESTEROL −0.013
             DIABETES            −0.011

  All correlations fall below ±0.03 — indicating near-zero
  statistical relationship between features and the target.
─────────────────────────────────────────────────────────────────

CRITICAL CAVEAT — SYNTHETIC DATASET
─────────────────────────────────────────────────────────────────
  The dataset is computer-generated, not collected from real patients.

  1. High accuracy is misleading.
     The model learns the generation pattern, not real medical
     signal. It would perform poorly on actual patient data.

  2. Near-zero correlations confirm no real signal exists.
     In reality, age, smoking, and cholesterol have well-documented
     links to heart disease. Their near-zero scores here are a
     direct result of synthetic randomization.

  3. The 50/50 class split is unrealistic.
     Real-world heart disease is not evenly distributed.
     Synthetic balance makes classification artificially easy.

  Bottom line: Any high accuracy achieved reflects the regularity
  of the synthetic data — not genuine predictive power.
─────────────────────────────────────────────────────────────────
════════════════════════════════════════════════════════════════
```

---

## System Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│          HEART DISEASE PREDICTION SYSTEM                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  DATA WAREHOUSE LAYER (Snowflake)                            │
│  ┌──────────────────────────────────────────────────┐        │
│  │  heart_raw (3 Partitioned Source Tables)         │        │
│  │  - heart_main        (primary records)           │        │
│  │  - heart_partial_one (partial batch 1)           │        │
│  │  - heart_partial_two (partial batch 2)           │        │
│  │  - 19 clinical & lifestyle features              │        │
│  │  - HEART_DISEASE_STATUS (target)                 │        │
│  └──────────────────────────────────────────────────┘        │
│                        ↓                                     │
│  TRANSFORMATION LAYER (dbt)                                  │
│  ┌──────────────────────────────────────────────────┐        │
│  │  heart_staging (Staging Layer)                   │        │
│  │  - Null imputation (MEDIAN, AVG, MODE by age/    │        │
│  │    gender partition)                             │        │
│  │  - Boolean encoding (SMOKING, DIABETES, etc.)    │        │
│  │  - Ordinal encoding (STRESS_LEVEL, EXERCISE, etc)│        │
│  │  - Filter rows where target IS NULL              │        │
│  │  - Randomised row order via ORDER BY RANDOM()    │        │
│  └──────────────────────────────────────────────────┘        │
│                        ↓                                     │
│  MART LAYER (dbt)                                            │
│  ┌──────────────────────────────────────────────────┐        │
│  │  heart_main        → 5,000 record sample         │        │
│  │  heart_partial_one → partial sample              │        │
│  │  heart_partial_two → partial sample              │        │
│  └──────────────────────────────────────────────────┘        │
│                        ↓                                     │
│  ML EXECUTION LAYER (Python / Jupyter)                       │
│  ┌──────────────────────────────────────────────────┐        │
│  │  snowflake_info.py         model.ipynb           │        │
│  │  ┌─────────────────┐       ┌──────────────────┐  │        │
│  │  │ Connect to      │  →    │ Merge 3 tables   │  │        │
│  │  │ Snowflake       │       │ (pd.concat)      │  │        │
│  │  └─────────────────┘       └──────────────────┘  │        │
│  │                                     ↓             │        │
│  │                            ┌──────────────────┐   │        │
│  │                            │ Correlation EDA  │   │        │
│  │                            │ Class Distribution│  │        │
│  │                            └──────────────────┘   │        │
│  │                                     ↓             │        │
│  │                            ┌──────────────────┐   │        │
│  │                            │ ML Model         │   │        │
│  │                            │ (Classification) │   │        │
│  │                            └──────────────────┘   │        │
│  └──────────────────────────────────────────────────┘        │
│                        ↓                                     │
│  OUTPUT LAYER                                                │
│  ┌──────────────────────────────────────────────────┐        │
│  │  Correlation table (all 19 features vs target)   │        │
│  │  Class distribution plots                        │        │
│  │  Model accuracy and evaluation metrics           │        │
│  └──────────────────────────────────────────────────┘        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## System Architecture

### Tech Stack Overview

| Layer                    | Technology                     | Purpose                                          |
|--------------------------|--------------------------------|--------------------------------------------------|
| Runtime Environment      | Python 3.12                    | Core application language                        |
| Machine Learning         | scikit-learn                   | Model training and evaluation                    |
| Data Transformation      | dbt (dbt-core + dbt-snowflake) | SQL-based data pipeline and staging              |
| Data Warehouse           | Snowflake                      | Cloud-based storage and querying                 |
| Data Connection          | snowflake-connector-python     | Python SDK for Snowflake connectivity            |
| Analysis & Visualization | pandas, seaborn, matplotlib    | EDA, correlation analysis, and count plots       |
| Notebook                 | Jupyter                        | Interactive analysis environment                 |

### Core Components

**1. Data Layer (Snowflake)**

- **Raw Source Tables**: Three tables hold the raw heart disease records — `heart_main`, `heart_partial_one`, and `heart_partial_two` — each sourced from the `HEART_DISEASE` database.
- **Mart Schema**: Exposes clean, sample-limited views for downstream use.
- **19 Features**: Covers age, gender, blood pressure, cholesterol, BMI, exercise, smoking, family history, diabetes, hypertension, HDL/LDL flags, alcohol, stress, sugar, sleep, triglycerides, CRP, and homocysteine.

**2. Transformation Layer (dbt)**

- **Staging Model** (`heart_staging.sql`): Transforms raw records into analysis-ready features.
  - Imputes missing values using `MEDIAN`, `AVG`, or `MODE` partitioned by age and gender.
  - Encodes boolean columns (`SMOKING`, `DIABETES`, `FAMILY_HEART_DISEASE`, etc.) to 0/1.
  - Converts ordinal text columns (`STRESS_LEVEL`, `EXERCISE_HABITS`, `ALCOHOL_CONSUMPTION`, `SUGAR_CONSUMPTION`) to numeric via the `convert_difficulty` macro.
  - Encodes `GENDER` as 1 (Male) or 2 (Female).
  - Filters out rows where `HEART_DISEASE_STATUS IS NULL`.
  - Randomises row order via `ORDER BY RANDOM()`.
- **Mart Models** (`heart_main.sql`, `heart_partial_one.sql`, `heart_partial_two.sql`): Expose staged data as clean 5,000-record samples for ML consumption.

**3. ML Execution Layer (Python)**

- **`snowflake_info.py`** — Data Connection Module
  - Loads credentials from `.env`.
  - Connects to Snowflake and queries the three mart tables.
  - Returns three pandas DataFrames (`df_main`, `df_p1`, `df_p2`).

- **`model.ipynb`** — Analysis and Modelling Notebook
  - Merges the three DataFrames via `pd.concat`.
  - Sorts by age and computes Pearson correlation of all features against `HEART_DISEASE_STATUS`.
  - Generates class distribution count plots using seaborn.
  - Trains and evaluates a classification model on the prepared features.

### Integration Flow

```
Snowflake (Raw: heart_main, heart_partial_one, heart_partial_two)
        ↓
dbt Transform (heart_staging.sql → mart models)
        ↓
Snowflake (Mart Schema: heart_main, heart_partial_one, heart_partial_two)
        ↓
snowflake_info.py (Python Retrieval → 3 DataFrames)
        ↓
model.ipynb (Merge → EDA → Correlation → ML Model)
        ↓
Output: Correlation Table + Class Distribution Plots + Model Metrics
```

---

## Operational Flow

### Step-by-Step Lifecycle

**Phase 1: Data Preparation**

1. Raw heart disease data is stored across three Snowflake tables.
2. Run `dbt run` to execute the transformation pipeline.
3. dbt executes `heart_staging.sql` which:
   - Reads raw data from the source schema.
   - Imputes nulls, encodes categoricals, and filters invalid rows.
   - Materialises the staging view in the `staging` schema.
4. Mart models expose 5,000-record samples ready for Python consumption.

**Phase 2: Analysis and Model Training**

1. Open `model.ipynb` in Jupyter.
2. Execution sequence:
   - `snowflake_info.py` loads credentials from `.env`.
   - Establishes a Snowflake connection and queries all three mart tables.
   - DataFrames are merged into a single dataset and sorted by age.
3. Correlation Analysis:
   - Pearson correlation computed for all 19 features vs. `HEART_DISEASE_STATUS`.
4. Class Distribution:
   - Count plots generated to visualise target class balance.
5. Model Training:
   - Features and target separated.
   - Train-test split applied.
   - Classification model trained and evaluated.

### User Journey

```
dbt Transform → Data Retrieval → EDA & Correlation → Model Training → Evaluation
```

---

## How to Run (Local Setup)

### Prerequisites

- Python 3.12 or higher
- Git for cloning the repository
- Snowflake account with warehouse and database configured
- dbt-snowflake installed

### Installation Steps

**Step 1: Clone Repository**

```bash
git clone <repository-url>
cd heart_disease_prediction
```

**Step 2: Create Python Virtual Environment**

```bash
python3.12 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

**Step 3: Install Dependencies**

```bash
pip install --upgrade pip
pip install dbt-snowflake snowflake-connector-python pandas seaborn matplotlib jupyter scikit-learn python-dotenv
```

**Step 4: Create Environment File**

Create a `.env` file in the project root:

```bash
# .env — Snowflake Configuration

SNOWFLAKE_USER=your_snowflake_username
SNOWFLAKE_PASSWORD=your_snowflake_password
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_WAREHOUSE=your_warehouse_name
SNOWFLAKE_DATABASE=your_database_name
SNOWFLAKE_SCHEMA=your_schema
```

### Running the Project

**Option A: Complete Pipeline (dbt + Analysis)**

```bash
# Step 1: Run dbt transformation pipeline
cd dbt_heart
dbt run
cd ../

# Step 2: Open the analysis notebook
jupyter notebook model.ipynb
```

**Option B: Analysis Only (Data Already Staged)**

```bash
jupyter notebook model.ipynb
```

### Verification

After running the pipeline, verify successful execution:

1. dbt logs show no model failures.
2. The notebook correlation cell outputs a full table of 19 feature correlations.
3. Count plot renders correctly showing class distribution.
4. Model accuracy metric is printed in the final notebook cell.

### Troubleshooting

| Issue                                              | Solution                                                          |
|----------------------------------------------------|-------------------------------------------------------------------|
| `ModuleNotFoundError: No module named 'snowflake'` | Run `pip install snowflake-connector-python`                      |
| Snowflake connection timeout                       | Verify `.env` credentials and Snowflake account status            |
| `dbt run` fails with "source not found"            | Ensure raw data tables exist in Snowflake's raw schema            |
| Empty DataFrame returned from Snowflake            | Ensure dbt transformation completed successfully                  |
| Notebook kernel crashes on concat                  | Confirm all three DataFrames are non-empty before merging         |

---

## Project Structure

```
heart_disease_prediction/
├── .env                          # Local credentials (git-ignored)
├── .gitignore
├── model.ipynb                   # EDA, correlation analysis, and ML model
├── snowflake_info.py             # Snowflake connection and data retrieval
└── dbt_heart/                    # dbt data transformation project
    ├── dbt_project.yml           # dbt project configuration
    ├── profiles.yml              # Snowflake connection profiles
    ├── models/
    │   ├── staging/
    │   │   ├── heart_staging.sql # Cleaning, encoding, and null imputation
    │   │   └── src_sources.yml   # Source table references
    │   └── mart/
    │       ├── heart_main.sql    # 5,000-record primary sample
    │       ├── heart_partial_one.sql
    │       ├── heart_partial_two.sql
    │       └── src_sources.yml
    ├── macros/                   # Custom dbt macros (convert_difficulty, convert_bool)
    └── logs/                     # dbt execution logs
```

---

## Script Reference

### `snowflake_info.py` — Data Connection

**Purpose**: Manages Snowflake authentication and data retrieval
**Uses**: Environment variables from `.env`
**Exports**: Three pandas DataFrames (`df_main`, `df_p1`, `df_p2`)
**Key Process**:

1. Loads credentials from `.env`.
2. Establishes Snowflake connector.
3. Executes queries against the three mart tables.
4. Returns clean DataFrames for use in the notebook.

### `model.ipynb` — Analysis and Modelling Notebook

**Purpose**: Performs EDA, correlation analysis, and classification modelling
**Inputs**: DataFrames from `snowflake_info.py`
**Outputs**: Correlation table, class distribution plots, model accuracy

**Key Process**:

1. Merges three DataFrames into a single dataset via `pd.concat`.
2. Sorts dataset by age.
3. Computes Pearson correlation of all 19 features vs. `HEART_DISEASE_STATUS`.
4. Generates count plots for class distribution.
5. Trains and evaluates a classification model.

### `heart_staging.sql` — dbt Staging Model

**Purpose**: Cleans and encodes raw Snowflake data for ML use
**Key Transformations**:

1. Imputes nulls using `MEDIAN` (age), `AVG` (blood pressure, cholesterol), or `MODE` (BMI, sleep, triglycerides, CRP, homocysteine) partitioned by age and gender.
2. Encodes boolean columns to 0/1.
3. Converts ordinal text columns to integers via the `convert_difficulty` macro.
4. Filters rows with a null target variable.
5. Randomises row order.

---

## Key Features & Capabilities

- **19-Feature Clinical Dataset**: Covers a broad range of cardiovascular risk factors.
- **Automated Data Pipeline**: dbt orchestrates all cleaning and encoding steps.
- **Enterprise Data Warehouse**: Snowflake stores and serves partitioned source data.
- **Partition-Aware Imputation**: Missing values filled using demographic-aware window functions.
- **Transparent Reporting**: Findings published alongside a clear disclosure of the synthetic dataset limitation.

---

## Limitations

| Issue                          | Impact                                                                 |
|--------------------------------|------------------------------------------------------------------------|
| Synthetic dataset              | Results are not applicable to real patients                            |
| Near-zero correlations         | No genuine predictive signal exists in the data                        |
| Balanced synthetic classes     | Masks real-world class imbalance of heart disease                      |
| 5,000 record sample per mart   | Limits generalization even within the synthetic space                  |
| No real noise or confounders   | Synthetic data lacks the complexity of real clinical observations       |

---

## Next Steps for Enhancement

- Source a real, validated clinical dataset (e.g., UCI Heart Disease, Framingham) to replace the synthetic data
- Implement advanced classifiers (XGBoost, LightGBM) and compare against a baseline
- Add hyperparameter tuning via GridSearchCV to optimize model performance
- Generate feature importance plots to interpret which clinical factors matter most
- Deploy model predictions as a REST API endpoint for real-time risk scoring
- Add a web interface for manual feature input and live prediction output
- Expand features with secondary markers such as ECG results, family history depth, and medication history

---

## Contributing

Ensure all dbt models run cleanly and the notebook executes end-to-end before submitting changes:

```bash
cd dbt_heart
dbt run
dbt test
cd ../
jupyter nbconvert --to notebook --execute model.ipynb
```

---

## Disclaimer

This project is for educational and portfolio purposes only. The dataset is synthetic and must not be used for any clinical or medical decision-making.
