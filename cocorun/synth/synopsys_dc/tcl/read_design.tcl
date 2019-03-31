
define_design_lib WORK -path ./WORK

{% for lib_name,lib_path in hdl_libraries.items() %}
define_design_lib  -path {{lib_path}}  {{lib_name}}
{% endfor %}

###The following variable helps verification when there are differences between DC and FM while inferring logical hierarchies 
set_app_var hdlin_enable_hier_map true


{% macro language_format(source) -%}
    {%if source.language.lower().startswith('vhdl') %} vhdl {% else %} verilog {%endif%}
{%- endmacro %}

{% for source in hdl_sources %}
    {% if source.lib %} 
analyze -format {{language_format(source)}} {{source.path}} -library {{source.lib}}
    {% else %}
analyze -format {{language_format(source)}} {{source.path}} -work work 
    {% endif %}
{% endfor %}

elaborate {{top_module_name}}

list_designs

current_design {{top_module_name}}

link