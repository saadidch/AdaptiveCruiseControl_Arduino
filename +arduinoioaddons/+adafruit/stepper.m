classdef stepper < arduinoio.MotorBase & matlab.mixin.CustomDisplay
%STEPPER Create a stepper motor device object.
    
% Copyright 2018 The MathWorks, Inc.
    
    properties(SetAccess = immutable)
        StepsPerRevolution
    end
    
    properties(Access = public)
        RPM = 0
    end
    
    properties (SetAccess = immutable)
        StepType
    end
    
    properties(Access = private)
        ResourceMode
        ResourceOwner
        MaxStepperMotors
        MaxStepsPerRevolution
    end
    
    properties(Access = private, Constant = true)
        % MATLAB defined command IDs
        CREATE_STEPPER     = hex2dec('06')
        RELEASE_STEPPER    = hex2dec('07')
        MOVE_STEPPER       = hex2dec('08')
        SET_SPEED_STEPPER  = hex2dec('09')
    end
    
    properties(Access = private, Constant = true)
        STEPTYPE_SINGLE     = 1
        STEPTYPE_DOUBLE     = 2
        STEPTYPE_INTERLEAVE = 3
        STEPTYPE_MICROSTEP  = 4
        
        ROTATE_FORWARD      = 1
        ROTATE_BACKWARD     = 2
    end
    
	%% Constructor
    methods(Hidden, Access = public)
        function obj = stepper(parentObj, motorNumber, stepsPerRevolution, varargin)
            obj.Pins = [];
            obj.MaxStepperMotors = 2;
            obj.MaxStepsPerRevolution = 2^15-1;
            obj.Parent = parentObj;
            arduinoObj = parentObj.Parent;
            
            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
            catch e
                throwAsCaller(e);
            end
            
            obj.ResourceOwner = 'AdafruitMotorShieldV2\Stepper';
            obj.ResourceMode = 'AdafruitMotorShieldV2\Stepper';
            motorNumber = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                [obj.ResourceOwner 'MotorNumber'], ...
                motorNumber, ...
                1, obj.MaxStepperMotors);
            
            stepsPerRevolution = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                [obj.ResourceOwner 'StepsPerRevolution'], ...
                stepsPerRevolution, ...
                1, obj.MaxStepsPerRevolution);
            obj.StepsPerRevolution = stepsPerRevolution;
            
            try
                steppers = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'steppers');
            catch
                locStepper = 1; %#ok<NASGU>
                steppers = [parentObj.I2CAddress zeros(1, obj.MaxStepperMotors)];
            end
            shieldStepperAddresses = steppers(:, 1);
            [~, locStepper] = ismember(parentObj.I2CAddress, shieldStepperAddresses);
            if locStepper == 0
                steppers = [steppers; parentObj.I2CAddress zeros(1, obj.MaxStepperMotors)];
                locStepper = size(steppers, 1);
            end
            
            % Check for resource conflict with Stepper Motors
            if steppers(locStepper, motorNumber+1)
                obj.localizedError('MATLAB:arduinoio:general:conflictStepperMotor', num2str(motorNumber));
            end

            % Check for resource conflict with DC Motors
            dcmotorResource = 'AdafruitMotorShieldV2\DCMotor';
            try
            dcmotors = getSharedResourceProperty(arduinoObj, dcmotorResource, 'dcmotors');
                shieldDCMotorAddresses = dcmotors(:, 1);
                [~, locDC] = ismember(parentObj.I2CAddress, shieldDCMotorAddresses);
                if locDC ~= 0
                    possibleConflictingDCMotorNumber = [floor((motorNumber-1)*2)+1, floor((motorNumber-1)*2)+2];
                    if any(dcmotors(possibleConflictingDCMotorNumber+1))
                        obj.localizedError('MATLAB:arduinoio:general:conflictStepperTerminals', ...
                            num2str(possibleConflictingDCMotorNumber(1)),...
                            num2str(possibleConflictingDCMotorNumber(2)),...
                            num2str(motorNumber));
                    end
                end
            catch e
                if ~strcmp(e.identifier, 'MATLAB:hwsdk:general:invalidResourceName')
                    throwAsCaller(e);
                end
            end

            % No clonflicts
            steppers(locStepper, motorNumber+1) = 1;
            setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'steppers', steppers);
            obj.MotorNumber = motorNumber;
            
            try
                p = inputParser;
                addParameter(p, 'RPM', 0);
                addParameter(p, 'StepType', 'Single');
                parse(p, varargin{:});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                    obj.ResourceOwner, ...
                    matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
            end
            
            stepTypeValues = {'Single', 'Double', 'Interleave', 'Microstep'};
            try
                obj.StepType = char(validatestring(p.Results.StepType, stepTypeValues));
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyValue',...
                    obj.ResourceOwner, ...
                    'StepType', ...
                    matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(stepTypeValues, ', '));
            end
            
            createStepper(obj);
            obj.RPM = p.Results.RPM;
        end
    end
    
    %% Public methods
    methods 
        function move(obj, steps)
            %   Move the stepper motor in the specified number of steps.
            %
            %   Syntax:
            %   move(dev, steps)
            %
            %   Description:
            %   Step the stepper motor for the specified number of steps
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       sm = stepper(shield,1,200,'RPM',10);
            %       move(sm, 10);
            %
            %   Input Arguments:
            %   dev       - DC motor device 
            %   steps     - The number of steps to move
            %
			%   See also release
            
            try
                try
                    if (nargin < 2)
                        obj.localizedError('MATLAB:minrhs');
                    end
                catch e
                    throwAsCaller(e);
                end
            
                maxSteps = 2^15-1;
                steps = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    'AdafruitMotorShieldV2\Stepper Steps', steps, -maxSteps, maxSteps);
                
                % Add 1ms base delay to each step move to count for I2C bus
                % 1K Hz speed to ensure receival of ACK when RPM, 
                % StepsPerRevolution and steps are all higih
                if obj.RPM > 0
                    if strcmp(obj.StepType, 'Single') || strcmp(obj.StepType, 'Double')
                        timeout = (floor(60000000/(obj.RPM*obj.StepsPerRevolution))+1)*abs(steps)/1000;
                    elseif strcmp(obj.StepType, 'Interleave')
                        timeout = (floor(60000000/(2*obj.RPM*obj.StepsPerRevolution))+1)*abs(steps)/1000;
                    else
                        timeout = (floor(60000000/(obj.RPM*obj.StepsPerRevolution*16))+1)*16*abs(steps)/1000;
                    end
                    moveStepper(obj, steps, timeout);
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function release(obj)
            %   Stop the stepper motor
            %
            %   Syntax:
            %   release(dev)
            %
            %   Description:
            %   Release the stepper motor to spin freely
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       sm = stepper(shield,1,200,'RPM',10);
            %       move(sm, 10);
            %       release(sm);
            %
            %   Input Arguments:
            %   dev       - stepper motor device 
            %
			%   See also move
            
            try
                releaseStepper(obj);
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.RPM(obj, rpm)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            
                maxRPM = 2^15-1;
                rpm = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    'Stepper RPM', rpm, 0, maxRPM);
                
                setSpeedStepper(obj, rpm);
                obj.RPM = rpm;
            catch e
                throwAsCaller(e);
            end
        end
    end
    
	%% Destructor
    methods (Access=protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                parentObj = obj.Parent;
                arduinoObj = parentObj.Parent;
                
                % Clear the Stepper Motor
                steppers = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'steppers');
                shieldDCAddresses = steppers(:, 1);
                [~, locStepper] = ismember(parentObj.I2CAddress, shieldDCAddresses);
                steppers(locStepper, obj.MotorNumber+1) = 0;
                setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'steppers', steppers);
                
                releaseStepper(obj);
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end
    
    %% Private methods
    methods (Access = private)
        function createStepper(obj)
            commandID = obj.CREATE_STEPPER;

            sprev = typecast(uint16(obj.StepsPerRevolution),'uint8');
            rpm = typecast(uint16(obj.RPM),'uint8');
            params = [sprev, rpm];
            sendCommand(obj, commandID, params');
        end
        
        function moveStepper(obj, steps, timeout)
            commandID = obj.MOVE_STEPPER;

            if steps > 0
                direction = obj.ROTATE_FORWARD;
            else
                direction = obj.ROTATE_BACKWARD;
            end
            
            switch obj.StepType
                case 'Single'
                    stepType = obj.STEPTYPE_SINGLE;
                case 'Double'
                    stepType = obj.STEPTYPE_DOUBLE;
                case 'Interleave'
                    stepType = obj.STEPTYPE_INTERLEAVE;
                case 'Microstep'
                    stepType = obj.STEPTYPE_MICROSTEP;
                otherwise
            end
            steps = typecast(uint16(abs(steps)),'uint8');
            params = [steps, direction, stepType];
            % specified timeout cannot be smaller than the default
            % timeout(5s)
            if timeout > 5 
                sendCommand(obj, commandID, params', timeout);
            else
                sendCommand(obj, commandID, params');
            end
        end
        
        function releaseStepper(obj)
            if isempty(obj.MotorNumber) % Nothing to release.
                return;
            end
            commandID = obj.RELEASE_STEPPER;

            params = [];
            sendCommand(obj, commandID, params);
        end
        
        function setSpeedStepper(obj, speed)
            commandID = obj.SET_SPEED_STEPPER;

            speed = typecast(uint16(speed),'uint8');
            sendCommand(obj, commandID, speed');
        end
    end
    
    %% Protected methods
    methods(Access = protected)
        function output = sendCommand(obj, commandID, params, timeout)
            params = [obj.MotorNumber - 1; params];
            if nargin < 4
                output = sendShieldCommand(obj.Parent, commandID, params);
            else
                output = sendShieldCommand(obj.Parent, commandID, params, timeout);
            end
        end
    end
        
    %% Protected methods
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options
            fprintf('           MotorNumber: %-15d\n', obj.MotorNumber);
            fprintf('    StepsPerRevolution: %-15d\n', obj.StepsPerRevolution);
            fprintf('                   RPM: %-15d\n', obj.RPM);  
            fprintf('              StepType: %s (''Single'', ''Double'', ''Interleave'', ''Microstep'')\n', obj.StepType);
            fprintf('\n');
                  
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end