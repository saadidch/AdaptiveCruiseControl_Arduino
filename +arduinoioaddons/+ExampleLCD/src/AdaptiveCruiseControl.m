a = arduino('com4','uno','libraries',{'ultrasonic','ExampleLCD/LCDAddon'}); %Initializing Arduino Libraries for LCD and Ultrasonic
u = ultrasonic(a,'D13','D12','OutputFormat','double'); %Defining Pins for Ultrasonic Sensor
lcd = addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D7','EnablePin','D6','DataPins',{'D5','D4','D3','D2'}); %Defining DataPins for LCD Display

initializeLCD(lcd, 'Rows', 2, 'Columns', 16); %Initializing LCD display

% Buttons for different commands
increase_btn=0;
decrease_btn=0;
cancel_btn  =0;
cruise_btn  =0;
adapcc_btn  =0;
cnt         =0;
speed       =0;

while true
    %Assiging buttons to analog pins of Arduino
    increase_btn = readVoltage(a,'A0');
    decrease_btn = readVoltage(a,'A2');
    cancel_btn   = readVoltage(a,'A3');
    cruise_btn   = readVoltage(a,'A4');
    adapcc_btn   = readVoltage(a,'A1');
    %Assigning the Ultrasonic Display
    distance     = readDistance(u);
    
    if cnt==0
        if increase_btn>=4.5  %For increase speed
            speed=speed+1;
    elseif decrease_btn>=4.5 %To decrease speed
                speed=speed-2;
            else
                speed=speed-1;
            end
    elseif cnt==1
             speed=speed;
    elseif cnt==2
                 if distance<0.25
                     speed=speed-1;
                 else
                     speed=speed+1;
                 end
                 if speed>speedlimit
                     speed=speedlimit;
                 end
             end
      if cruise_btn>=4.5 %Normal Cruise Control Command
          cnt=1;
      elseif adapcc_btn>=4.5 %Adaptive Cruise Control Command
              cnt=2;
              speedlimit=speed;
      elseif cancel_btn>=4.5 %Cancel Button Command
              cnt=0;
      elseif increase_btn>=4.5 && cnt~=2
          speed=speed+1;
      elseif decrease_btn>4.5 && cnt~=2
          speed=speed-1;
      end
      
      if speed<0
          speed=0;
      end
     
      distance = distance*100;
      diss = append('Dist. ',num2str(distance),' m'); %Displaying Distancce on LED
      spee = append('Speed ',num2str(speed)); %Displaying Speed on LCD
      printLCD(lcd,spee);
      printLCD(lcd,diss);

end
