# Create a Vivado project in syn/vivado so generated files stay out of repo root.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set proj_name "int8-systolic-mac-array"
set proj_dir [file join $repo_root syn vivado]

file mkdir $proj_dir
create_project -force $proj_name $proj_dir -part xc7a100tcsg324-1

# Add design and testbench sources from repository folders.
add_files -fileset sources_1 [file join $repo_root rtl pe.sv]
add_files -fileset constrs_1 [file join $repo_root syn constraints.xdc]
add_files -fileset sim_1 [file join $repo_root test pe_tb.sv]

set_property top pe [get_filesets sources_1]
set_property top pe_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Vivado project created at: $proj_dir/$proj_name.xpr"
