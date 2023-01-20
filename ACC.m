% Defining Variables & Initialization
a = arduino('com3','uno','BaudRate',9600,'libraries',{'ultrasonic','ExampleLCD/LCDAddon'},'ForceBuildOn',true);
u = ultrasonic(a,'D9','D10','OutputFormat','double');
lcd = addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D2','EnablePin','D3','DataPins',{'D7','D6','D5','D4'});

initializeLCD(lcd);

speed=0; 
input=0; % Button input
cruise_set=0; % Cruise Control Configuration (ON/OFF)
adaptive_cruise_mode=0; % Adaptive Cruise Control Configuration (ON/OFF)
cc_speed=0; % Cruise Control Speed
adapt_cc=0; % Adaptive Cruise Control Speed
% Pin Configuration
% Increase button – D10
% Decrease button – A5
% Cruise set button - D11
% Adaptive speed set button - D12
% Cancel button - D13
while true 
while true
 increase=readDigitalPin(a_object,'D13'); 
 decrease=readDigitalPin(a_object,'A2'); 
 ccontrol=readDigitalPin(a_object,'D12'); 
 adapt=readDigitalPin(a_object,'D11'); 
 cancel_input=readDigitalPin(a_object,'D8'); 
 if(increase==1)
 input=1; 
 break;
 elseif(decrease==1) 
 input=2; 
 break;
 elseif(ccontrol==1) 
 cruise_set=1; 
 cc_speed=speed; % Lock speed to cruise speed
 break; 
 elseif(adapt==1) 
 adaptive_cruise_mode=1; 
 adapt_cc=speed; % Lock speed to adapt speed
 break;
 elseif(cancel_input==1) 
 cruise_set=0; 
 adaptive_cruise_mode=0; 
 cc_speed=0; 
 adapt_cc=0; 
 break;
 else
 input=0; 
 break;
 end
end
switch input 
 case 1 
 speed=speed+1; % increase speed on pressing button 1
 case 2 
 if (speed>0) 
 speed=speed-1; % decrease speed on pressing button 1
 end
 otherwise 
 if(speed>0 && cruise_set==0 && adaptive_cruise_mode==0) 
 speed=speed-1; % Decrease speed on not pressing anything
 elseif(adaptive_cruise_mode==1) 
 d=(readDistance(sensor))*100; % If adapt pin is pressed; Read sensor data 
 if(d<15 && speed>0) 
 speed=speed-1; % if senor distance is less than 15 and reduce 
speed;
 elseif(speed<adapt_cc) 
 speed=speed+1; % if current speed is less than cruise speed; 
increase until cruise speed
 end
 printLCD(lcd,char("")); % Blink speed 
 pause(15); 
 end
 
end
printLCD(lcd,char("Speed: "+speed+" mph")); % Display LCD with the current speed based 
on button response.
pause(15); 
thingSpeakWrite(1458804,speed,'WriteKey','SX733LGYM0SQFLC9');
end