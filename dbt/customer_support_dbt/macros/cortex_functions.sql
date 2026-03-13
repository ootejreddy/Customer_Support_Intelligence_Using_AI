{% macro cortex_translate(text, source_lang, target_lang) %}
    {{ return("SNOWFLAKE.CORTEX.TRANSLATE(" ~ text ~ ", " ~ source_lang ~ ", " ~ target_lang ~ ")") }}
{% endmacro %}

{% macro cortex_sentiment(text) %}
    {{ return("SNOWFLAKE.CORTEX.SENTIMENT(" ~ text ~ ")") }}
{% endmacro %}

{% macro cortex_classify_text(text, categories) %}
    {{ return("SNOWFLAKE.CORTEX.CLASSIFY_TEXT(" ~ text ~ ", " ~ categories ~ ")") }}
{% endmacro %}

{% macro cortex_complete(model, prompt) %}
    {{ return("SNOWFLAKE.CORTEX.COMPLETE(" ~ model ~ ", " ~ prompt ~ ")") }}
{% endmacro %}
