create_clock -period {{ period|round(3, 'floor') }} -name {{name}} [get_ports {{port_name}}]

