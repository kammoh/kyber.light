
from jinja2 import Template, Environment, PackageLoader, select_autoescape

env = Environment(
    loader=PackageLoader('.', 'templates'),
    autoescape=select_autoescape(['tcl'])
)


template = env.get_template('vivado.tcl')
print(template.render(name='John Doe'))
