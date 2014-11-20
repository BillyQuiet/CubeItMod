CubeItMod
=========

CUBEITMOD From original Evanery's CubeIt and Giovanni.V CubeItMod V4.9.2  
KISSlicer BFB GCode post-processor for 3DS CubeX 3D printer compatibility  
AutoIt Script

Usage
------
If Input File is Provided in Command Line, then Process without GUI (as a Kisslicer Post-Processor) Call as  

    CUBEITMOD V4.10.0 {InputFileName}
 
Where **{InputFileName}** is the name of the file to process (will be saved as *.BAK)



Config.ini
------
- Sparse infill Patch Tweak   
**default = 1**  
**sample 0.3 = 30%**    
**sample 0.5 = 50%**
> M108_RPM_speed_Factor=0.3  

- Max X Y Speed Factor (1/x%)  
**default = 0.1**  
**sample 0.1 = X10**  
**sample 0.05 = X20**  
> Max_XY_speed_factor=0.05  

- Max F Speed    
**default = 25000**  
> Max_F_speed=30000

