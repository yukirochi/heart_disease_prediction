WITH raw_data AS (
    SELECT * FROM {{ source('heart_raw_data', 'heart_raw') }}
),

typed AS (
    SELECT
        COALESCE(AGE, MEDIAN(AGE) OVER())::NUMERIC        AS age_l,
        CASE WHEN LOWER(GENDER) = 'male' THEN 1 ELSE 2 END AS gender_l,
        LOWER(ALCOHOL_CONSUMPTION) AS alc,
        LOWER(STRESS_LEVEL) AS sl,
        LOWER(SUGAR_CONSUMPTION) as sc,
        LOWER(EXERCISE_HABITS) as eh,
        *
    FROM raw_data
),

cleaned AS (
    SELECT
        age_l AS age,
        gender_l AS gender,
        COALESCE(BLOOD_PRESSURE,    AVG(BLOOD_PRESSURE)    OVER (PARTITION BY age, gender))::NUMERIC AS blood_pressure,
        COALESCE(CHOLESTEROL_LEVEL, AVG(CHOLESTEROL_LEVEL) OVER (PARTITION BY age, gender))::NUMERIC AS cholesterol_level,
        ROUND(COALESCE(BMI, MODE(BMI) OVER (PARTITION BY age, gender))::FLOAT, 2)                    AS bmi,
        {{ convert_difficulty('eh')}} AS exercise_habits,
        {{ convert_bool('SMOKING') }}               AS smoking,
        {{ convert_bool('FAMILY_HEART_DISEASE') }}  AS family_heart_disease,
        {{ convert_bool('DIABETES') }}              AS diabetes,
        {{ convert_bool('HIGH_BLOOD_PRESSURE') }}   AS high_blood_pressure,
        {{ convert_bool('LOW_HDL_CHOLESTEROL') }}   AS low_hdl_cholesterol,
        {{ convert_bool('HIGH_LDL_CHOLESTEROL') }}   AS low_ldl_cholesterol,
        {{ convert_difficulty('alc')}} AS alcohol_consumption,
        {{ convert_difficulty('sl')}} AS stress_level,
        {{ convert_difficulty('sc')}} AS sugar_consumption,
        ROUND(COALESCE(SLEEP_HOURS::FLOAT, MODE(SLEEP_HOURS) OVER( PARTITION BY age, gender))::FLOAT,2) AS sleep_hours,
        COALESCE(TRIGLYCERIDE_LEVEL, MODE(TRIGLYCERIDE_LEVEL) OVER( PARTITION BY age, gender))::NUMERIC AS triglyceride_level,
        ROUND(COALESCE(CRP_LEVEL::FLOAT, MODE(CRP_LEVEL) OVER( PARTITION BY age, gender))::FLOAT,2) AS crp_level,
        ROUND(COALESCE(HOMOCYSTEINE_LEVEL::FLOAT, MODE(HOMOCYSTEINE_LEVEL) OVER( PARTITION BY age, gender))::FLOAT,2) AS homocysteine_level,
        CASE WHEN HEART_DISEASE_STATUS::BOOL = TRUE THEN 1 ELSE 0 END  AS heart_disease_status

    FROM typed
    WHERE HEART_DISEASE_STATUS IS NOT NULL
)

SELECT * FROM cleaned