
/*
UoM-RS-Arduino_Firmware.ino
--------------------------
Licenting Information: You are free to use or extend this project
for educational purposes provided that (1) you do not distribute or
publish solutions, (2) you retain this notice, and (3) you provide 
clear attribution to the University of Melbourne, Department of 
Mechanical Engineering and Product Design Lab.

Attribution Information: The ChessBot project was developed in collaboration
between Product Design Lab & the University of Melbourne. The core project was 
primarily developed by Professor Denny Oetomo (doetomo@unimelb.edu.au). All 
Starter Code and libraries were developed by Nathan Batham of Product
Design Lab
(nathan@productdesignlab.com.au)

*/



#include <Robotics_Systems_Library.h> 

#define TIMESTEP_MILLISECONDS 3   // Target Loop rate

// Create global robot object
UOM_RS_Robot robot;

// Initialise global timers
unsigned long tic = 0, toc = 0, timer = 0;



void setup() {
  
  // Connect to Arduino to MATLAB
  robot.EstablishUSBConnection();

  // Connect to Motors
  robot.EstablishMotorSerialConnection();
  
  // Read ID of connected motors & send to MATLAB
  robot.getID();
  robot.sendMotorIDs();
  
  // Read initial feedback & set internal position variable
  robot.InitMotorFeedback();

}

void loop() {

  // Begin measuring execution time
  tic = millis();

  // Finite State Machine
  switch (state) {
    case IDLE:
      
      // Check for input for MATLAB
      if (robot.connection_status == 1) {
        state = robot.getState();
      }
      
      break;

    case READ_FB:

      // Read mtor feedback
      robot.ReadFeedback();

      // Send feedback to MATLAB
      robot.SendFB2MATLAB();

      // Return to IDLE state
      state = IDLE;
      break;

    case DRIVE_MOTOR:

      // Read reference position/velocity from MATLAB
      robot.getReference(); 

      // Drive motors to reference
      robot.DriveMotors();

      // Return to IDLE state
      state = IDLE;
      break;
      

    case UPDATE_DRIVE_MODE:

      // Read motor control mode from MATLAB and update motors
      robot.getControlMode();

      // Return to IDLE state
      state = IDLE;
      break;
      
      
    default:
      state = IDLE;
      break;
  }


  // Measure loop time
  toc = millis();
  timer = toc - tic;

  // Wait until the full time-step unless running late.
  if (timer > TIMESTEP_MILLISECONDS) {
    return;
  }
  

}
