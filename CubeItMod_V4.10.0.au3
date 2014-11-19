#Region
#AutoIt3Wrapper_UseX64=n
#EndRegion

; PROGRAM:  CUBEITMOD V4.10.0 From original Evanery's CubeIt
; FUNCTION: BFB GCode (Kisslicer) post-processor for CubeX Compatibility

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>

Global $InputFile, $SuckM227[4], $SuckM228[4], $PrimeM227[4], $PrimeM228[4], $SuckPrimeSpeed[4], $UseM227, $UseM228, $nSuckM227[4], $nSuckM228[4], $nPrimeM227[4], $nPrimeM228[4], $nSuckPrimeSpeed[4]
Global $ActualRPM, $NewXYF , $InfillPerimeterFactor[4], $SolidPerimeterFactor[4], $nFlow[4] , $nGain[4] , $ActualXYF , $nDiameter[4], $nExtrusionWidth, $nInfillExtrusionWidth , $nLayerThickness
Global $Extruders = 0 , $Extruding = 0 , $MaxRPMfactor = 0, $WarningMSG="" , $FlagMsg=0 , $Filling=0, $Soliding =0 , $Perimetering = 0 , $Looping=0
Global $AverageSolidLenght , $Line ,$hInput , $nStack , $Stacking = 0 , $InfillStyle, $Once = 0 , $BedRoughness=0 , $BedOffsetZ=0 ,$PrintingFirstLayer=False

Global $Conf_M108SpeedFactor = 1 , $Conf_MaxXYspeedfactor = 0.1 , $Conf_MaxFSpeed = 25000

Global $MaxSpeed_calc=0

Command_Line_Or_GUI()

Get_Config()

Check_KISSlicer_Comments()

StringToNumber();Change alphanumericals variables into numerical variables

ProcessFile() ;Main Job

Messages_Box()

Exit

;--------------------------------------------------------------------------------------------------


Func Messages_Box()
	Local $Extruder_Msg, $M227_Msg, $M228_Msg ;Done Message

	For $i=1 To $Extruders

		$Extruder_Msg &= @CRLF & "Extruder N°" & $i & @CRLF & "M227 P" & String(int($nPrimeM227[$i]*2962)) &  " S" & String (int($nSuckM227[$i]*2962)) & @CRLF  & "M228 P" & String(int($nPrimeM228[$i]*2962))& " S" & String(int($nSuckM228[$i]*2962))& @CRLF & "Solid% = " & String($SolidPerimeterFactor[$i]*100) & @CRLF & "Infill% = " & String($InfillPerimeterFactor[$i]*100) & "   Infill X/Y speed multiplied by " & String (Round((1/$InfillPerimeterFactor[$i]),2)) & @CRLF
	Next

	; Check if very low RPM ( = X/Y speed incrased by more than 25%) was present on Kisslicer's BFB and if so display warning message.
	If $MaxRPMFactor > 1.25 Then
		$WarningMsg = "*** Warning *** : according to fit the lowest Cubex's RMP" & @CRLF & "some X/Y speeds are incresed by " & String( 100*(Round(($MaxRPMFactor)-1,1))) & "%" & @CRLF & "You can try to add a pillar or incrase the layer thickness or incrase the speeds or reduce the min time layer to reduce this effect" & @CRLF
		$FlagMsg=48
	EndIf
	
	if $MaxSpeed_calc>$Conf_MaxFSpeed then
		$WarningMsg = @CRLF & $WarningMsg & "------------------> ATTENTION Vitesse trop grande Modifier le parametre Conf_MaxXYspeedfactor<-----------------" & @CRLF
		$FlagMsg=19
	endif

	; display M227/228 use
	If $UseM227 = "1" then
		$M227_Msg = "M227 Turned ON"
	Else
		$M227_Msg = "M227 Turned OFF"
	EndIf

	If $UseM228 = "1" then
		$M228_Msg = "M228 Turned ON"
	Else
		$M228_Msg = "M228 Turned OFF"
	EndIf

	; display M108 S Coef
	if 	$Conf_M108SpeedFactor = "1" then
		$Conf_M108SpeedFactor_msg = "M108 Sparse Infill Patch RPM Coefficient Turned OFF (" & $Conf_M108SpeedFactor & ")"
	Else
		$Conf_M108SpeedFactor_msg = "M108 Sparse Infill Patch RPM = " & String($Conf_M108SpeedFactor*100) &" % (" & $Conf_M108SpeedFactor & ")"
	EndIf

	$MaxXYspeedfactor_msg = "Max X Y speed factor = " & "x" & String(1/$Conf_MaxXYspeedfactor) & " (" & $Conf_MaxXYspeedfactor & ")"

	; Done!
	MsgBox($FlagMsg,"CubeItMod V4.10.0 Completed!", _
		"Config.ini"					       & @CRLF & _	
		"Conf_M108SpeedFactor=" 	& String($Conf_M108SpeedFactor) & @CRLF & _	
		"Max_XY_speed_factor=" 		& String($Conf_MaxXYspeedfactor) 	& @CRLF & _
		"Conf_MaxFSpeed=" 	    	& String($Conf_MaxFSpeed) 	& @CRLF & _
		"--------------------------------"     & @CRLF & _
		"MaxSpeedF="& String($MaxSpeed_calc)   & @CRLF & _
		"--------------------------------"     & @CRLF & _
		$M227_Msg                              & @CRLF & _
		$M228_Msg                              & @CRLF & _
		"--------------------------------"     & @CRLF & _			
		$Conf_M108SpeedFactor_msg              & @CRLF & _
		$MaxXYspeedfactor_msg                  & @CRLF & _
		"--------------------------------"     & @CRLF & _
		$Extruder_Msg                          & @CRLF & _
		$WarningMsg                            & @CRLF & _
		"--------------------------------"     & @CRLF & _
		"New File: "& $InputFile               & @CRLF & _
		"Original File: " & $InputFile & ".bak")
EndFunc

Func Command_Line_Or_GUI()
if $CmdLine[0] > 0 Then
	$InputFile = $CmdLine[1]
Else
	$InputFile = FileOpenDialog("CubeItMod V4.10.0: Please Select an Input File", @WorkingDir, "BFB Files (*.BFB)|All Files (*.*)", 1)
EndIf
EndFunc

Func Check_KISSlicer_Comments()
; Scan the KISSLICER Comments in the Input File to get P & S for M227 and M228 values + other variables
If GetPrimeSuck() = 0 Then FatalError("Can't Find Materials Info in Print File." & @CRLF & "(Kisslicer Comments must be turned ON!)")
EndFunc

Func GetPrimeSuck();Get Infos from original BFB file

Local 	$Extruder
		$Extruder_Count_Key = 			"; num_extruders = "
		$Extruder_Section_Key = 		"; *** Material Settings for Extruder "
		$M227S_Key = 					"; destring_suck = "
		$M227P_Key = 					"; destring_prime = "
		$M228S_Key = 					"; cost_per_cm3 = "
		$M228P_Key = 					"; sec_per_c_per_c = "
		$SuckPrimeSpeed_Key = 			"; destring_speed_mm_per_s = "
		$UseM227_key = 					"; use_destring = "
		$UseM228_key = 					"; fan_pwm = "
		$Bed_Key = 						"; bed_C = "
		$Flow_Key = 					"; flowrate_tweak = "
		$Gain1_Key = 					"; ext_gain_1 = "
		$Gain2_Key = 					"; ext_gain_2 = "
		$Gain3_Key = 					"; ext_gain_3 = "
		$ExtrusionWidth_Key = 			"; extrusion_width_mm = "
		$InfillExtrusionWidth_Key = 	"; infill_extrusion_width = "
		$LayerThickness_Key = 			"; layer_thickness_mm = "
		$Diameter_Key = 				"; fiber_dia_mm = "
		$Stack_Key = 					"; stacked_layers = "
		$Infill_Style_Key = 			"; infill_st_oct_rnd = "
		$BedOffsetZ_Key = 				"; bed_offset_z_mm = "
		$BedRoughness_Key = 			"; bed_roughness_mm = "


	$hInput = FileOpen($InputFile)

	$Hits = 0
	$Extruder = 0
	; Process the Input File's Header Line by Line
	While 1
		$line = FileReadLine($hInput)
		If @error = -1 Then ExitLoop

		 ;Get the number of used extruders
		If StringLeft($line, StringLen($Extruder_Count_Key)) = $Extruder_Count_Key Then
			$Extruders = ASC(StringMid($line, StringLen($Extruder_Count_Key) + 1, 1)) - 48
			$Hits += 1

		;Get the current extruder Number
		ElseIf StringLeft($line, StringLen($Extruder_Section_Key)) = $Extruder_Section_Key Then
			$Extruder = ASC(StringMid($line, StringLen($Extruder_Section_Key) + 1, 1)) - 48
			$Hits += 1

		 ;Get Gain S value for extruder 1
		ElseIf StringLeft($line, StringLen($Gain1_Key)) = $Gain1_Key Then
			$nGain[1] = number(StringTrimLeft($Line,StringLen($Gain1_Key)))
			$Hits += 1

		;Get Gain S value for extruder 2
		ElseIf StringLeft($line, StringLen($Gain2_Key)) = $Gain2_Key Then
			$nGain[2] = number(StringTrimLeft($Line,StringLen($Gain2_Key)))
			$Hits += 1

		;Get Gain S value for extruder 3
		ElseIf StringLeft($line, StringLen($Gain3_Key)) = $Gain3_Key Then
			$nGain[3] = number(StringTrimLeft($Line,StringLen($Gain3_Key)))
			$Hits += 1

		 ;Get Flow Tweak for current extruder
		ElseIf StringLeft($line, StringLen($Flow_Key)) = $Flow_Key Then
			$nFlow[$Extruder] = StringTrimLeft($Line,StringLen($Flow_Key))
			$Hits += 1

		 ;Get M227 S value for current extruder
		ElseIf StringLeft($line, StringLen($M227S_Key)) = $M227S_Key Then
			$SuckM227[$Extruder] = StringTrimLeft($Line,StringLen($M227S_Key))
			$Hits += 1

		;Get M227 P value for current extruder
		ElseIf StringLeft($line, StringLen($M227P_Key)) = $M227P_Key Then
			$PrimeM227[$Extruder] = StringTrimLeft($Line,StringLen($M227P_Key))
			$Hits += 1

		 ;Get M228 S value for current extruder
		ElseIf StringLeft($line, StringLen($M228S_Key)) = $M228S_Key Then
			$SuckM228[$Extruder] = StringTrimLeft($Line,StringLen($M228S_Key))
			$Hits += 1

		 ;Get M228 P value for current extruder
		ElseIf StringLeft($line, StringLen($M228P_Key)) = $M228P_Key Then
			$PrimeM228[$Extruder] = StringTrimLeft($Line,StringLen($M228P_Key))
			$Hits += 1

		 ;Get the speed of Suck/Prime for current extruder, used to change RPM while "Filling"
		ElseIf StringLeft($line, StringLen($SuckPrimeSpeed_Key)) = $SuckPrimeSpeed_Key Then
			$SuckPrimeSpeed[$Extruder] = StringTrimLeft($Line,StringLen($SuckPrimeSpeed_Key))
			$InfillPerimeterFactor[$Extruder]= (number($SuckPrimeSpeed[$Extruder]) / 100)
			if $InfillPerimeterFactor[$Extruder] <= 0.01 then FatalError ( "Infill% must be > 1, if you dont want to use it set 100, set more than 100 to increase the quantity of material deposed while ""Filling"" and less than 100 to decrease the quantity of material deposed while ""Filling""")
			$Hits += 1

		 ;Get the Bed temp to use to change RPM while extruding Solid
		ElseIf StringLeft($line, StringLen($Bed_Key)) = $Bed_Key Then
			$SolidPerimeterFactor[$Extruder] = (number(StringTrimLeft($Line,StringLen($Bed_Key)))/100)
			if $SolidPerimeterFactor[$Extruder] = 0 then FatalError ( "Solid% must be > 0, if you dont want to use it set 100, set more than 100 to increase the quantity of material deposed while ""making Solid"" and less than 100 to decrease quantity of material deposed while ""making Solid""")
			$Hits += 1

		 ;Get the Diameter Filament on each extruder
		ElseIf StringLeft($line, StringLen($Diameter_Key)) = $Diameter_Key Then
			$nDiameter[$Extruder] = number(StringTrimLeft($Line,StringLen($Diameter_Key)))
			$Hits += 1

		 ; Get Extrusion width
	    ElseIf StringLeft($line, StringLen($ExtrusionWidth_Key)) = $ExtrusionWidth_Key Then
		$nExtrusionWidth = number(StringTrimLeft($Line,StringLen($ExtrusionWidth_Key)))
			$Hits += 1

		 ; Get Infill Extrusion width
	    ElseIf StringLeft($line, StringLen($InfillExtrusionWidth_Key)) = $InfillExtrusionWidth_Key Then
		$nInfillExtrusionWidth = number(StringTrimLeft($Line,StringLen($InfillExtrusionWidth_Key)))
			$Hits += 1

		 ; Get Bed Roughness
	    ElseIf StringLeft($line, StringLen($BedRoughness_Key)) = $BedRoughness_Key Then
		$BedRoughness = number(StringTrimLeft($Line,StringLen($BedRoughness_Key)))
			$Hits += 1

		 ; Get Bed Offset Z
	    ElseIf StringLeft($line, StringLen($BedOffsetZ_Key)) = $BedOffsetZ_Key Then
		$BedOffsetZ = number(StringTrimLeft($Line,StringLen($BedOffsetZ_Key)))
			$Hits += 1

		 ; Get Layer Thickness
	    ElseIf StringLeft($line, StringLen($LayerThickness_Key)) = $LayerThickness_Key Then
		$nLayerThickness = number(StringTrimLeft($Line,StringLen($LayerThickness_Key)))
			$Hits += 1

		 ; Get how many layers are stacked
		 ElseIf StringLeft($line, StringLen($Stack_Key)) = $Stack_Key Then
		 $nStack = number(StringTrimLeft($Line,StringLen($Stack_Key)))
			$Hits += 1

		 ; Check infill style if Straight
		 ElseIf StringLeft($line, StringLen($Infill_Style_Key)) = $Infill_Style_Key Then
		 $InfillStyle = number(StringTrimLeft($Line,StringLen($Infill_Style_Key)))
			if $InfillStyle > 0 Then
			   If $Once = 0 then
				  MsgBox ( 48, "Infill Style not Straight" , "Cubeitmod has better control on Straight Infill Style." & @CRLF & @CRLF & "You're still free to choose another style." & @CRLF & @CRLF & "This message is automatically closed after 4 seconds.", 4 )
				  $Once +=1
			   Endif
			EndIf
			$Hits += 1

		; If = 0 destring M227 OFF, if =1 destring M227 ON
	    ElseIf StringLeft($line, StringLen($UseM227_Key)) = $UseM227_Key Then
		$UseM227 = StringTrimLeft($Line,StringLen($UseM227_Key))
			$Hits += 1

		 ; If = 0 destring M228 OFF, if =1 destring M228 ON, if >1 Error
	    ElseIf StringLeft($line, StringLen($UseM228_Key)) = $UseM228_Key Then
		$UseM228 = StringTrimLeft($Line,StringLen($UseM228_Key))
			$Hits += 1

		 ; Stop the search at the end ot the header
		 Elseif StringInStr ($Line, "Main G-Code")>0 Then
		 ExitLoop
		 EndIf

	WEnd

	FileClose($hInput)

	Return $Hits
EndFunc

Func ProcessFile();Main Job

Local $TxtExtruder, $OldRPM, $nExtr, $SolidFactor
Local $FirstAfterWarming = 0
Local $YPos , $ZPos , $X1 , $X2 , $Y1 , $Y2 , $n = 0  , $FilePos , $SolidLenght = 0
Local $OldLine , $InfillLenght = 0 , $InfillFactor , $Layer

	FileMove($InputFile, $InputFile & ".bak", 1)
	$hInput  = FileOpen($InputFile & ".bak")
	$hOutput = FileOpen($InputFile, 2)

	; Process the Input File Line by Line
	While 1
		$line = FileReadLine($hInput)
		If @error = -1 Then ExitLoop

		; Eliminate Blank Lines
		If $line = "" Then ContinueLoop

		;Look if is printing the first layer and Bed Roughness is > 0
		If $BedRoughness > 0 then
			if StringLeft ($line,Stringlen("; BEGIN_LAYER_OBJECT z=")) = "; BEGIN_LAYER_OBJECT z=" Then
				$Layer = StringTrimLeft ($line,Stringlen("; BEGIN_LAYER_OBJECT z="))
				if $Layer = $nLayerThickness + $BedRoughness + $BedOffsetZ then
					$PrintingFirstLayer = True
				Else
					$PrintingFirstLayer = False
				EndIf
			Endif
		EndIf

		; Get Working Extruder = $TxTExtruder and Set $FirstAfterWarming to 1
		If StringLeft ($line,22) =Stringleft("; *** Warming Extruder",22) Then
			$TxtExtruder = StringMid ($line,24,1)
			$nExtr = Number($TxtExtruder)
			$FirstAfterWarming = 1
		EndIf

		; Set $Filling or $Soliding or $Stacking or $Perimetering Looping var to 1 if doing Infill or Solid or Stack or Perimeter
		If ((StringInStr ( $Line , "Infill Path'")) > 1 ) or ((StringInStr ( $Line , "Infill'")) > 1 )Then
			$Filling = 1
			If (StringInStr ( $Line , "Stacked") > 1 ) Then
				$Stacking = 1
			Else
				$Stacking = 0
			EndIf
			$OldLine = $Line
			$FilePos = FileGetPos ( $hInput )
			$Line = FileReadLine ( $hInput )
			if StringLeft ( $Line , 4 ) = "G1 X" Then
				$YPos = StringInStr ( $Line , "Y")
				$ZPos = StringInStr ( $Line , "Z")
				$X1 = number ( StringMid ( $Line , 5 , $Ypos-2))
				$Y1  = Number ( StringMid ( $Line , $YPos+1 , $ZPos-2))
			Else
				MsgBox (1, "ERROR " & $Line, "No G1 Line")
			EndIf
			FileSetPos ( $hInput , $FilePos, $FILE_BEGIN )
			$Line = $OldLine
		EndIf
		
		If ((StringInStr ( $Line , "'Solid Path'")) > 1)  or ((StringInStr ( $Line , "'Solid'")) > 1) Then
			$Soliding = 1
			$OldLine = $Line
			$FilePos = FileGetPos ( $hInput )
			$Line = FileReadLine ( $hInput )
			if StringLeft ( $Line , 4 ) = "G1 X" Then
				$YPos = StringInStr ( $Line , "Y")
				$ZPos = StringInStr ( $Line , "Z")
				$X1 = number ( StringMid ( $Line , 5 , $Ypos-2))
				$Y1  = Number ( StringMid ( $Line , $YPos+1 , $ZPos-2))
			Else
				MsgBox (1, "ERROR " & $Line, "No G1 Line")
			EndIf
			FileSetPos ( $hInput , $FilePos, $FILE_BEGIN )
			$Line = $OldLine
		EndIf
		
		If ((StringInStr ( $Line , "'Perimeter Path'")) > 1) or ((StringInStr ( $Line , "'Perimeter'")) > 1) Then
			$Perimetering = 1
		EndIf
		
		If  ((StringInStr ( $Line , "'Loop Path'")) > 1) or ((StringInStr ( $Line , "'Loop'")) > 1) Then
			$Looping = 1
		Endif

		; Eliminate Comments and unused M227
		If StringLeft($line, 1) = ";" Or StringLeft ($line,4)="M227" Then ContinueLoop
		
		; Place M227 & M228 with S and P values from Kisslicer
		If StringLeft($line,4) = "M55" & $TxtExtruder and $UseM227 = "1" Then
			FileWriteLine($hOutput,"M227 P"& String (Int($nPrimeM227[$nExtr]*2962))& " S" & String (Int($nSuckM227[$nExtr]*2962)))
			If $UseM228 = "1" Then
				FileWriteLine($hOutput,"M228 P"& String (Int($nPrimeM228[$nExtr]*2962))& " S" & String (Int($nSuckM228[$nExtr]*2962)))
			EndIf
		EndIf

		;Place the first M103 to Suck before first layer and avoid initial blob
		; change RPM to real RPMs that the Cubex can do
		If StringLeft($line,4) = "M"&$TxtExtruder&"08" Then
			$OldRPM = Number ( Stringmid ($line , 7))
			If $FirstAfterWarming = 1 Then
				If $OldRPM < 1 then
					$ActualRPM = 1
					If ($ActualRPM / $OldRPM)> $MaxRPMFactor Then
						$MaxRPMFactor = ($ActualRPM/$OldRPM)
					EndIf
				Else
					$ActualRPM = Int ($OldRPM)
				EndIf
				FileWriteLine ($hOutput,"M" & $TxtExtruder & "08 S" & String ($ActualRPM))
				$line = "M103"
				$FirstAfterWarming = 0
			Else
				; look for furure 		
				$OldLine = $Line
				$FilePos = FileGetPos ( $hInput )
				
				$Line = FileReadLine ( $hInput ) ; 1st next line				
				$Line = FileReadLine ( $hInput ) ; 2nd next line				
				
				If ((StringInStr ( $Line , "'Sparse Infill Path'")) > 1 ) then
					;MsgBox($MB_SYSTEMMODAL, "", "Line :" & $Line & " OldRpm :" & $OldRPM & "[" & StringInStr ( $Line , "'Sparse Infill Path'") & "]")
					$OldRPM = $OldRPM * $Conf_M108SpeedFactor
				EndIf
			
				FileSetPos ( $hInput , $FilePos, $FILE_BEGIN )
				$Line = $OldLine				
				; end future look 
			
				If $OldRPM < 1 then
					$ActualRPM = 1
					If ($ActualRPM / $OldRPM)> $MaxRPMFactor Then
						$MaxRPMFactor = ($ActualRPM/$OldRPM)
					EndIf
				Else
					$ActualRPM = Int ($OldRPM)
				EndIf
				$line = ("M" & $TxtExtruder & "08 S" & String ($ActualRPM))
			EndIf
		EndIf

		; Set $Extruding var to 1 when extrusion starts
		If StringLeft($Line,4) = "M"&$TxtExtruder&"01" then $Extruding=1

			; Calculate and write F speed according to real RPM cubex value for Perimeter and Loop
			; look if "Filling" and if so change RPM with the InfillPeirmeterFactor
			; look if "Soliding" and if so calculate the lenght of each line then calculate the $SolidFactor for the line
			; Permimeter, Solid and Infill speeds are calculated from the settigns values
			; other speeds are calculated form the values calculated by Kisslicer ( at the moment )
			If StringLeft($line,4)="G1 X" and $Extruding=1 Then
				If $Filling = 1 Then
					if $InfillStyle = 0 then
						$YPos = StringInStr ( $Line , "Y")
						$ZPos = StringInStr ( $Line , "Z")
						$X2 = number ( StringMid ( $Line , 5 , $Ypos-2))
						$Y2 = Number ( StringMid ( $Line , $YPos+1 , $ZPos-2))	
						$InfillLenght = Sqrt ( ( $X2 - $X1)^2 + ( $Y2 - $Y1 )^2)
						
						If $Stacking = 1 then
							If $InfillLenght > -( - 1.5 + 3 * $nLayerThickness * $nStack ) then
								$InfillFactor = ((-1)/($InfillPerimeterFactor[$nExtr]*( (-1.5 + 3 * $nLayerThickness * $nStack ) + $InfillLenght)^1.1))+ 1.05
								If $InfillFactor < $Conf_MaxXYspeedfactor then
									$InfillFactor = $Conf_MaxXYspeedfactor
									If $InfillFactor <  ( $nLayerThickness * $nStack ) then
										$InfillFactor =  ( $nLayerThickness * $nStack )
									EndIf
								Endif
							Else
								$InfillFactor = ( $nLayerThickness * $nStack )
							Endif
						
						Elseif $Stacking = 0 Then
							If $InfillLenght > -( - 1.5 + 3 * $nLayerThickness ) then
								$InfillFactor = ((-1)/($InfillPerimeterFactor[$nExtr]*( (-1.5 + 3 * $nLayerThickness ) + $InfillLenght)^1.1))+ 1.05
								If $InfillFactor < $Conf_MaxXYspeedfactor then
									$InfillFactor = $Conf_MaxXYspeedfactor
									If $InfillFactor <  ( $nLayerThickness ) then
										$InfillFactor =  ( $nLayerThickness )
									EndIf
								Endif
							Else
								$InfillFactor = ( $nLayerThickness )
							EndIf
							
						Else
							MsgBox ( 0 , "Error" , "Infill line with undefined Stack status " )
						EndIf
						
						If $PrintingFirstLayer = False Then
							$NewXYF = Round ($ActualRPM * ($nDiameter[$nExtr])^2 /(11.82 * $nStack * $nInfillExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr] * $InfillFactor ),1)
						Elseif $PrintingFirstLayer = True Then
							$NewXYF = Round (($ActualRPM * $nLayerThickness/($nLayerthickness + $BedRoughness) )* ($nDiameter[$nExtr])^2 /(11.82 * $nStack * $nInfillExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr] * $InfillFactor ),1)
						EndIf
						
						$X1 = $X2
						$Y1 = $Y2
						$line = StringLeft($line , StringinStr ( $line , "F")) & String ($NewXYF)
					Else
						$ActualXYF = Number ( StringTrimLeft( $line ,(StringInStr ( $line , "F"))))
						If $ActualRPM = 1 Then
							$NewXYF= Round ($ActualXYF/($OldRPM*$InfillPerimeterFactor[$nExtr]),1)
						Else
							$NewXYF = Round ($ActualRPM*$ActualXYF/($OldRPM * $InfillPerimeterFactor[$nExtr]),1)
						EndIf
						$line = StringLeft($line , StringinStr ( $line , "F")) & String ($NewXYF)
					Endif
				Elseif $Soliding = 1 Then
					$YPos = StringInStr ( $Line , "Y")
					$ZPos = StringInStr ( $Line , "Z")
					$X2 = number ( StringMid ( $Line , 5 , $Ypos-2))
					$Y2 = Number ( StringMid ( $Line , $YPos+1 , $ZPos-2))
					$SolidLenght = Sqrt ( ( $X2 - $X1)^2 + ( $Y2 - $Y1 )^2)
					
					If $SolidLenght > -( - 1.5 + 3 * $nLayerThickness ) then
						$SolidFactor = ((-1)/($SolidPerimeterFactor[$nExtr]*(( - 1.5 + 3 * $nLayerThickness ) + $SolidLenght)^1.1))+ 1.05
						If $SolidFactor < $Conf_MaxXYspeedfactor then
							$SolidFactor = $Conf_MaxXYspeedfactor
							If $SolidFactor < $nLayerThickness Then
								$SolidFactor = $nLayerThickness
							EndIf
						EndIf
					Else
						$SolidFactor = $nLayerThickness
					Endif
					
					If $PrintingFirstLayer = False Then
						$NewXYF = Round ($ActualRPM * ($nDiameter[$nExtr])^2 /(11.82 * $nExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr] * $SolidFactor ),1)
					Elseif $PrintingFirstLayer = True Then
						$NewXYF = Round (($ActualRPM * $nLayerThickness/($nLayerthickness + $BedRoughness) )* ($nDiameter[$nExtr])^2 /(11.82 * $nExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr] * $SolidFactor ),1)
					EndIf
					$X1   = $X2
					$Y1   = $Y2
					$line = StringLeft($line , StringinStr ( $line , "F")) & String ($NewXYF)
					
				Elseif $Perimetering = 1  or $Looping = 1 Then
					If $PrintingFirstLayer = False Then
						$NewXYF = Round ($ActualRPM * ($nDiameter[$nExtr])^2 /(11.82 * $nExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr]),1)
					Elseif $PrintingFirstLayer = True Then
						$NewXYF = Round (($ActualRPM * $nLayerThickness/($nLayerthickness + $BedRoughness) ) * ($nDiameter[$nExtr])^2 /(11.82 * $nExtrusionWidth * $nLayerThickness * $nFlow[$nExtr] * $nGain[$nExtr]),1)
					EndIf
					$line = StringLeft($line , StringinStr ( $line , "F")) & String ($NewXYF)
				Else
					$ActualXYF = Number ( StringTrimLeft( $line ,(StringInStr ( $line , "F"))))
					If $ActualRPM = 1 Then
						$NewXYF= Round ($ActualXYF/($OldRPM),1)
					Else
						$NewXYF = Round ($ActualRPM*$ActualXYF/$OldRPM,1)
					EndIf
					$line = StringLeft($line , StringinStr ( $line , "F")) & String ($NewXYF)
				Endif
				
				; Get Max speed For info
				if $NewXYF>$MaxSpeed_calc then
					$MaxSpeed_calc = $NewXYF
				endif
				
			EndIf

		;At the end of the printing path some vars are set to 0
		if StringLeft($line,4) = "M103" Then
			$Extruding    = 0
			$Filling      = 0
			$Soliding     = 0
			$Perimetering = 0
			$Looping      = 0
		EndIf

		; Write the Line
		FileWriteLine($hOutput, $line)

	WEnd

	FileClose($hInput)
	FileClose($hOutput)

EndFunc

Func StringToNumber();Conversion of alphanumerical variables into numerical variables
   Local $Count
   $Count =0
   For $Count = 1 to 3
	  $nSuckM227[$Count] = Number ($SuckM227[$Count])
	  $nPrimeM227[$Count] = Number ($PrimeM227[$Count])
	  $nSuckM228[$Count] = Number ($SuckM228[$Count])
	  $nPrimeM228[$Count] = Number ($PrimeM228[$Count])
	  $nSuckPrimeSpeed[$Count] = Number ($SuckPrimeSpeed[$Count])
	Next

EndFunc

Func IsSet($line, $str)
	If StringLeft($line, StringLen($str)) = $str then
		if StringTrimLeft($line,StringLen($str)) = "" then
			return false
		else
			return true
		endif
		
	Else
		return false
	EndIf
EndFunc

Func GetValueFromString($line, $str)
	$val = number(StringTrimLeft($line,StringLen($str)))				
	return $val
EndFunc

Func Get_Config()
	; Initialize config
	
	Local Const $sFilePath = @ScriptDir & "\Config.ini"
	Local $aArray = FileReadToArray($sFilePath)

	
	If @error Then
        MsgBox($MB_SYSTEMMODAL, "", "There was an error reading the config file. @error: " & @error) ; An error occurred reading the current script file.
    Else
        For $i = 0 To UBound($aArray) - 1 ; Loop through the array.
			$line = $aArray[$i]
			;MsgBox($MB_SYSTEMMODAL, "", $line)
			
			$str = "Max_XY_speed_factor="
			If IsSet($line,$str) then
				$Conf_MaxXYspeedfactor = GetValueFromString($line, $str )  ; 1/x%
			EndIf
			
			$str = "Max_F_speed="
			If IsSet($line,$str) then
				$Conf_MaxFSpeed = GetValueFromString($line, $str )  
			EndIf
			
			$str = "M108_RPM_speed_Factor="
			If IsSet($line,$str) then
				$Conf_M108SpeedFactor = GetValueFromString($line, $str )  
			EndIf
						
        Next
    EndIf
		
EndFunc

Func FatalError($msg)
		MsgBox(0, "CUBEITMOD V4.10.0 Fatal Error!", $msg)
		Exit
EndFunc
