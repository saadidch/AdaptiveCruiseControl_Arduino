/**
 * @file MotorShieldV2Base.h
 *
 * Class definition for MotorShieldV2Base class that wraps APIs of Adafruit Motor Shield V2 library
 *
 * @copyright Copyright 2014-2018 The MathWorks, Inc.
 *
 */

#include "LibraryBase.h"
#include "Adafruit_MotorShield.h"
#include "utility/Adafruit_MS_PWMServoDriver.h"

#define MIN_I2C 0x60
#define MAX_I2C 0x80

#ifdef MW_UNO_SHIELDS
#define MAX_SHIELDS 4
#else
#define MAX_SHIELDS 32
#endif

#define MAX_DCMOTORS 4
#define MAX_STEPPERMOTORS 2

Adafruit_MotorShield *AFMS[MAX_SHIELDS];
Adafruit_DCMotor *DCMotors[MAX_SHIELDS][MAX_DCMOTORS];
Adafruit_StepperMotor *StepperMotors[MAX_SHIELDS][MAX_STEPPERMOTORS];
        
// Arduino trace commands
const char MSG_MSV2_CREATE_MOTOR_SHIELD[]        PROGMEM = "Adafruit::AFMS[%d] = new Adafruit_MotorShield(%d)->begin(%d);\n";
const char MSG_MSV2_DELETE_MOTOR_SHIELD[]        PROGMEM = "Adafruit::delete AFMS[%d];\n";
const char MSG_MSV2_CREATE_DC_MOTOR[]            PROGMEM = "Adafruit::AFMS[%d]->getMotor(%d);\n";
const char MSG_MSV2_START_DC_MOTOR[]             PROGMEM = "Adafruit::DCMotors[%d][%d]->setSpeed(%d);\nDCMotors[%d][%d]->run(%d);\n";
const char MSG_MSV2_RELEASE_DC_MOTOR[]           PROGMEM = "Adafruit::DCMotors[%d][%d]->run(4);\n";
const char MSG_MSV2_SET_SPEED_DC_MOTOR[]         PROGMEM = "Adafruit::DCMotors[%d][%d]->setSpeed(%d);\nDCMotors[%d][%d]->run(%d);\n";
const char MSG_MSV2_CREATE_STEPPER_MOTOR[]       PROGMEM = "Adafruit::AFMS[%d]->getStepper(%d, %d)-->0x%04X;\nStepperMotors[%d][%d]->setSpeed(%d);\n"; 
const char MSG_MSV2_MOVE_STEPPER_MOTOR[]         PROGMEM = "Adafruit::-->0x%04X;StepperMotors[%d][%d]->step(%d, %d, %d);\n";
const char MSG_MSV2_RELEASE_STEPPER_MOTOR[]      PROGMEM = "Adafruit::StepperMotors[%d][%d]->release();\n";
const char MSG_MSV2_SET_SPEED_STEPPER_MOTOR[]    PROGMEM = "Adafruit::StepperMotors[%d][%d]->setSpeed(%d);\n";

#define CREATE_MOTOR_SHIELD 0x00
#define DELETE_MOTOR_SHIELD 0x01
#define CREATE_DC_MOTOR     0x02
#define START_DC_MOTOR      0x03
#define STOP_DC_MOTOR       0x04
#define SET_SPEED_DC_MOTOR  0x05
#define CREATE_STEPPER      0x06
#define RELEASE_STEPPER     0x07
#define MOVE_STEPPER        0x08
#define SET_SPEED_STEPPER   0x09
        
class AdafruitMotorShieldTrace {
public:
    // motorshield
    static void createMotorShield(byte shieldnum, byte i2caddress, unsigned int pwmfreq) {
        if(shieldnum < MAX_SHIELDS){
            if (NULL != AFMS[shieldnum]) {
                delete(AFMS[shieldnum]);
                AFMS[shieldnum] = NULL;
            }
            AFMS[shieldnum] = new Adafruit_MotorShield(i2caddress);
            AFMS[shieldnum]->begin(pwmfreq);
            debugPrint(MSG_MSV2_CREATE_MOTOR_SHIELD, shieldnum, i2caddress, pwmfreq);
        }
    }
    
    static void deleteMotorShield(byte shieldnum) {
        if(shieldnum < MAX_SHIELDS){
            delete AFMS[shieldnum];
            AFMS[shieldnum] = NULL;
            debugPrint(MSG_MSV2_DELETE_MOTOR_SHIELD, shieldnum);
        }
    }
    
    // DC motor
    static void createDCMotor(byte shieldnum, byte motornum) {
        if(shieldnum < MAX_SHIELDS){
            DCMotors[shieldnum][motornum] = AFMS[shieldnum]->getMotor(motornum+1);
            debugPrint(MSG_MSV2_CREATE_DC_MOTOR, shieldnum, motornum+1);
        }
    }
    
    static void startDCMotor(byte shieldnum, byte motornum, unsigned int speed, byte direction) {
        if(shieldnum < MAX_SHIELDS){
            DCMotors[shieldnum][motornum]->setSpeed(speed);
            DCMotors[shieldnum][motornum]->run(direction);
            debugPrint(MSG_MSV2_START_DC_MOTOR, shieldnum, motornum, speed, shieldnum, motornum, direction);
        }
    }
    
    static void stopDCMotor(byte shieldnum, byte motornum) {
        if(shieldnum < MAX_SHIELDS){
            DCMotors[shieldnum][motornum]->run(4);
            debugPrint(MSG_MSV2_RELEASE_DC_MOTOR, shieldnum, motornum);
        }
    }

    static void setSpeedDCMotor(byte shieldnum, byte motornum, unsigned int speed, byte direction) {
        if(shieldnum < MAX_SHIELDS){
            DCMotors[shieldnum][motornum]->setSpeed(speed);
            DCMotors[shieldnum][motornum]->run(direction);
            debugPrint(MSG_MSV2_SET_SPEED_DC_MOTOR, shieldnum, motornum, speed, shieldnum, motornum, direction);
        }
    }

    // Stepper motor
    static void createStepperMotor(byte shieldnum, byte motornum, unsigned int sprev, unsigned int rpm) {
        if(shieldnum < MAX_SHIELDS){
            StepperMotors[shieldnum][motornum] = AFMS[shieldnum]->getStepper(sprev, motornum+1);
            StepperMotors[shieldnum][motornum]->setSpeed(rpm);
            debugPrint(MSG_MSV2_CREATE_STEPPER_MOTOR, shieldnum, sprev, motornum+1, StepperMotors[shieldnum][motornum], shieldnum, motornum, rpm);
        }
    }
    
    static void moveStepperMotor(byte shieldnum, byte motornum, unsigned int steps, byte direction, byte steptype) {
        if(shieldnum < MAX_SHIELDS){
            StepperMotors[shieldnum][motornum]->step(steps, direction, steptype);
            debugPrint(MSG_MSV2_MOVE_STEPPER_MOTOR, StepperMotors[shieldnum][motornum], shieldnum, motornum, steps, direction, steptype);
        }
    }
    
    static void releaseStepperMotor(byte shieldnum, byte motornum) {
        if(shieldnum < MAX_SHIELDS){
            StepperMotors[shieldnum][motornum]->release();
            debugPrint(MSG_MSV2_RELEASE_STEPPER_MOTOR, shieldnum, motornum);
        }
    }
    
    static void setSpeedStepperMotor(byte shieldnum, byte motornum, unsigned int rpm) {
        if(shieldnum < MAX_SHIELDS){
            StepperMotors[shieldnum][motornum]->setSpeed(rpm);
            debugPrint(MSG_MSV2_SET_SPEED_STEPPER_MOTOR, shieldnum, motornum, rpm);
        }
    }
};

class MotorShieldV2Base : public LibraryBase
{
	public:
		MotorShieldV2Base(MWArduinoClass& a)
		{
            libName = "Adafruit/MotorShieldV2";
			a.registerLibrary(this);
		}
        
        void setup(){
            for (int i = 0; i < MAX_SHIELDS; ++i) {
                AFMS[i] = NULL;
            }
        }
		
	// Implementation of LibraryBase
	//
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            switch (cmdID){
                // Motor shield
                case CREATE_MOTOR_SHIELD:{
                    byte shieldnum = dataIn[0];
                    byte i2caddress = dataIn[1];
                    unsigned int pwmfreq = dataIn[2]+(dataIn[3]<<8);
                    AdafruitMotorShieldTrace::createMotorShield(shieldnum, i2caddress, pwmfreq) ;
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case DELETE_MOTOR_SHIELD:{ 
                    byte shieldnum = dataIn[0];
                    
                    AdafruitMotorShieldTrace::deleteMotorShield(shieldnum);
                            
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                
                // DC motor
                case CREATE_DC_MOTOR:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum = dataIn[1];
                    
                    AdafruitMotorShieldTrace::createDCMotor(shieldnum, motornum);
                            
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case START_DC_MOTOR:{
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    byte speed      = dataIn[2];
                    byte direction  = dataIn[3];
                    
                    AdafruitMotorShieldTrace::startDCMotor(shieldnum, motornum, speed, direction);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;    
                }
                case STOP_DC_MOTOR:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    
                    AdafruitMotorShieldTrace::stopDCMotor(shieldnum, motornum);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SET_SPEED_DC_MOTOR:{
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    byte speed      = dataIn[2]; 
                    byte direction  = dataIn[3];
                    
                    AdafruitMotorShieldTrace::setSpeedDCMotor(shieldnum, motornum, speed, direction);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                
                // Stepper Motor
                case CREATE_STEPPER:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1]; 
                    unsigned int sprev = dataIn[2]+(dataIn[3]<<8); 
                    unsigned int rpm = dataIn[4]+(dataIn[5]<<8);
                            
                    AdafruitMotorShieldTrace::createStepperMotor(shieldnum, motornum, sprev, rpm);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case RELEASE_STEPPER:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    
                    AdafruitMotorShieldTrace::releaseStepperMotor(shieldnum, motornum);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case MOVE_STEPPER:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    unsigned int steps = dataIn[2]+(dataIn[3]<<8);
                    byte direction  = dataIn[4];
                    byte steptype   = dataIn[5];
                    
                    AdafruitMotorShieldTrace::moveStepperMotor(shieldnum, motornum, steps, direction, steptype);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SET_SPEED_STEPPER:{ 
                    byte shieldnum = dataIn[0];
                    byte motornum   = dataIn[1];
                    unsigned int rpm = dataIn[2]+(dataIn[3]<<8);
                    
                    AdafruitMotorShieldTrace::setSpeedStepperMotor(shieldnum, motornum, rpm);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                default:
					break;
            }
		}
};