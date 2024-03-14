
// MOTOR ID CHANGE TOOL

/*
UoM-RS-Change_Motor_ID.ino
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

// Library Inclusions
#include <SMS_STS.h>


// Global Definitions
#define MAX_ID 6                                // Number of motors

// Global Variables
SMS_STS st;                                       // Motor Object used to send & receive motor data
long int motorBaudRate = 1000000;                // BaudRate used between Arduino and Motors
long int usbBaudRate = 115200;                  // BaudRate used between MATLAB and Arduino
u8 ID[MAX_ID] = {255, 255, 255, 255, 255, 255};
u8 newID[MAX_ID] = {255, 255, 255, 255, 255, 255};
int numID = 0;


void setup() {
  // Setup USB Serial
  Serial.begin(usbBaudRate);    // Set serial baud rate for USB
  while (!Serial);              // Wait For Serial To Connect

  // Setup Motor Serial
  Serial1.begin(motorBaudRate); // Set serial baud rate for motors
  while (!Serial1);             // Wait For Serial To Connect
  st.pSerial = &Serial1;        // Assign serial port to motor

  // Read Connected Motors & Get IDs
  numID = getID(ID);

  printHeader();


  

  if (numID == 1) {
    Serial.println("Connected motor ID: " + String(ID[0]));
    Serial.print("Enter new motor ID: ");
    while (Serial.available() == 0) {}     //wait for data available
    String teststr = Serial.readString();  //read until timeout
    teststr.trim();                        // remove any \r \n whitespace at the end of the String
    int motorID = teststr.toInt();
    Serial.println(motorID);

    Serial.print("Changing motor ID " + String(ID[0]) + " -> ID " + String(motorID) + ". Confirm? (y/n): ");
    while (Serial.available() == 0) {}     //wait for data available
    teststr = Serial.readString();  //read until timeout
    teststr.trim();                        // remove any \r \n whitespace at the end of the String
    Serial.println(teststr);
    if (teststr == "y") {

      changeID(ID[0], motorID);
    }
    else {
      
      Serial.println("ID update cancelled.");
    }

    numID = getID(newID);
    if (newID[0] == motorID) {
      Serial.println("New motor ID: " + String(newID[0]));
      Serial.println("ID updated successfully. Exiting.");
    }
    else {
      Serial.println("ID update FAILED. Exiting.");
    }
    
    
  }
  else {
    Serial.println("ERROR: Too many motors connected!");
    Serial.println("Number of Connected IDs = " + String(numID));
    Serial.print("Connected IDs: ");
    for (int i=0; i<MAX_ID; i++) {
      Serial.print(String(ID[i]) + ", ");
    }
    Serial.println();
    Serial.println("Ensure ONLY ONE motor is connected to change ID. Please disconnect additional motors and reset the Arduino.");
    Serial.println("ID update FAILED. Exiting.");
  }
  

}

void loop() {
  

}


int getID(u8 *ID) {

  // Get the number if motors connected and their IDs.

  // External Variables
  // @ ID       - Array of connected motor IDs.

  // Internal Variables
  // @ numID    - Number of connected IDs.
  // @ tempID   - Temporary value for storing pre-checked ID value.
  // @ SCSCL_ID - EPROM reference for accessing motor ID.

  // Internal Functions
  // readByte() - Read a byte of data returned by the motors.

  int numID = 0;


  for (int i = 1; i <= MAX_ID; i++) {
    // Read ID value from motor
    int tempID = st.readByte(i, SMS_STS_ID);

    // If returned ID is valid, store.
    if (tempID > 0 && tempID <= MAX_ID) {
      ID[numID] = tempID;
      numID++;
    }

  }

  return numID;
}

void printHeader() {
  Serial.println();
  Serial.println("##########################");
  Serial.println("## MOTOR ID CHANGE TOOL ##");
  Serial.println("##########################");
  Serial.println();
}


void changeID(u8 oldID, u8 newID) {

  // Tune the PID values of the specified motor. This only has an effect
  // when in position control mode. All gains must be whole numbers.


  // Unlock EPROM
  st.unLockEprom(oldID);
  delay(200);

  // Change Values
  st.writeByte(oldID, SMS_STS_ID, newID);
  delay(200);

  // Lock EPROM
  st.LockEprom(newID);
  delay(200);


}
