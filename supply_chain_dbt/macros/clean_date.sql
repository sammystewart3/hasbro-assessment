{% macro clean_date(column_name) %}
    date(
        case
            -- Handle MM/DD/YYYY slash dates (e.g. 07/28/2026)
            when {{ column_name }} like '__/__/____' then
                substr({{ column_name }}, 7, 4) || '-' || substr({{ column_name }}, 1, 2) || '-' || substr({{ column_name }}, 4, 2)

            -- Handle M/D/YYYY or MM/D/YYYY slash dates without leading zeros (e.g. 7/4/2026 or 11/4/2026)
            when {{ column_name }} like '_/__/____' then
                substr({{ column_name }}, 6, 4) || '-0' || substr({{ column_name }}, 1, 1) || '-' || substr({{ column_name }}, 3, 2)

            -- Handle YYYY/MM/DD slash dates
            when {{ column_name }} like '____/__/__' then
                replace({{ column_name }}, '/', '-')

            -- Handle standard YYYY-MM-DD dates
            when {{ column_name }} like '____-__-__' then
                {{ column_name }}

            else null
        end
    )
{% endmacro %}
