{% macro convert_bool(column_name, partition_cols="age, gender") %}

    CASE 
        WHEN {{ column_name }} = TRUE  THEN 1
        WHEN {{ column_name }} = FALSE THEN 0
        ELSE COALESCE(
            CASE 
                WHEN MODE({{ column_name }}) OVER (PARTITION BY {{ partition_cols }}) = TRUE  THEN 1
                WHEN MODE({{ column_name }}) OVER (PARTITION BY {{ partition_cols }}) = FALSE THEN 0
                ELSE 0
            END,
            0
        )
    END

{% endmacro %}