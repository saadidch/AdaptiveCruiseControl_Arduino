a = arduino('com3','uno','libraries',{'ultrasonic','ExampleLCD/LCDAddon'}); %Initializing Arduino Libraries for LCD and Ultrasonic
lcd = addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D7','EnablePin','D6','DataPins',{'D5','D4','D3','D2'}); %Defining DataPins for LCD Display
initializeLCD(lcd, 'Rows', 2, 'Columns', 16); %Initializing LCD display

printLCD(lcd,'6');