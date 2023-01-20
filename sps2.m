clc;
clear all;
a = arduino('com3','uno','libraries',{'servo','ExampleLCD/LCDAddon'});
s=servo(a,'D9','MinPulseDuration',700*10^-6,'Maxpulseduration',2300*10^-6); % Giving Servo motor connection 
lcd=addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D7','EnablePin','D6','DataPins',{'D5','D4','D3','D2'});
NumberOfCars=0;  %Initially no car is there and parking is empty
availablespace=13; %We have total 13 available space for parking 


%Now let’s give connection to lcd libraries and connection 

initializeLCD(lcd,'Rows', 2, 'Columns', 16);  % initializing LCD 


%%Defining Push buttons for entry and exit
configurePin(a,'A1','DigitalInput')
configurePin(a,'A2','DigitalInput') 
%%Defining LED lights
writeDigitalPin(a,'D13',1); 
writeDigitalPin(a,'D12',0);
writePosition(s,0); 
  
% at first lcd is clear 
clearLCD(lcd); 

printLCD(lcd,'SMART PARKING SYSTEM');
printLCD(lcd,'Team Number 19');
printLCD(lcd,'Faaiz Amin Qazi - 110061475');
printLCD(lcd,'Siva Subramanian Sreekanth - 110080270');
printLCD(lcd,'Arvind Ravikumar  - 110073481');
printLCD(lcd,"Let's Start");
printLCD(lcd,['Available Parking Space',num2str(availablespace)]) ;
%using while condition to manipulate number of parking slots, red and green
%light and servo motor

while 1  % This will run in loop till the condition is true
    enter_push=readDigitalPin(a,'A1');
    exit_push=readDigitalPin(a,'A2');
    if NumberOfCars==0 && availablespace==13 && exit_push==true 
			clearLCD(lcd);
            printLCD(lcd,'There is no car to exit')
	end	
	if NumberOfCars==13 && availablespace==0 && enter_push==true
			clearLCD(lcd);
            printLCD(lcd,'Sorry!! No space available, Please come after some time')
	end	
	if availablespace>0
        if enter_push==true 
            clearLCD(lcd);
            printLCD(lcd,'Welcome to the parking service')
            availablespace=availablespace-1;
            writeDigitalPin(a,'D12',1);
            writeDigitalPin(a,'D13',0);
            writePosition(s,0.5)
            pause(2) 
            writePosition(s,0)
            str1='Empty slots = '; 
            str2=num2str(availablespace); 
            printLCD(lcd,strcat(str1,str2));
        end
        writeDigitalPin(a,'D12',0);
        writeDigitalPin(a,'D13',1);
    else
        clearLCD(lcd); 
        printLCD(lcd,'No Space'); 
    end
    if availablespace<13
        if exit_push==true 
            writeDigitalPin(a,'D12',1); 
            writeDigitalPin(a,'D13',0); 
            clearLCD(lcd); 
            printLCD(lcd,'Thank you!! Please visit Again') 
            availablespace=availablespace+1; 
            str1='Empty slots = ';
            str2=num2str(availablespace); 
            printLCD(lcd,strcat(str1,str2)); 
            writePosition(s,0.5)
            pause(2)
            writePosition(s,0)
        end
        writeDigitalPin(a,'D12',0); 
        writeDigitalPin(a,'D13',1); 
    end
end
