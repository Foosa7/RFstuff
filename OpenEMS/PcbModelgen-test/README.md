# KiCad PCBModelgen on WSL2 and MATLAB

# Steps
1. Copy the template
2. Edit the KiCad file
3. Edit the json file
4. Run pcbmodelgen to generate the mesh: ```$ pcbmodelgen -p pcb.kicad_pcb -c pcbmodelgen.json -m kicad_pcb_model.m -g kicad_pcb_mesh.m ```
5. Import the kicad_pcb_mesh.m, kicad_pcb_model.m, simulation_script.m to Windows
6. Run simulation_script.m on Windows MATLAB
7. Import the .vtk files on ParaView to view the simulation
