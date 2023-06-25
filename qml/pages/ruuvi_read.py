"""Read raw data from RuuviTag device.

Implementation is based on Bleak example at
https://github.com/hbldh/bleak/blob/develop/examples/uart_service.py
and forum post on Ruuvi forums by Chris81
https://f.ruuvi.com/t/longlife-reading-log-history/5687/5

The RuuviTag bluetooth documentation can be find at
https://docs.ruuvi.com/communication/bluetooth-connection

License:
    Skruuvi - Reader for Ruuvi sensors
    Copyright (C) 2023  Miika Malin

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see [http://www.gnu.org/licenses/].
"""
import pyotherside
import sys
import threading
import asyncio
import struct
from time import time, sleep
# Add python packages to path to be able to import
sys.path.append("/usr/share/harbour-skruuvi")
import bleak

# Destinations
TEMPERATURE = 0x30
HUMIDITY = 0x31
AIR_PRESSURE = 0x32
ALL_SENSORS = 0x3A
# Charasteristic UUIDS
UART_RX_CHAR_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
UART_TX_CHAR_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
# Magic value for log read
LOG_READ = 0x11


class RuuviTagReader:
    def __init__(self):
        # Run as thread
        self.bgthread = threading.Thread()
        self.bgthread.start()

        self.device_address = None
        self.destination = None
        self.start_timestamp = None
        self.log_data_end_of_data = False
        # Use keyword data to distuinguish when data is sent with pyotherside
        self.received_data = ["data"]
        self.data_received_amount = 0

    def handle_disconnect(self, _):
        # Send signal if we havent received the log_data_end_of_data
        # This means that something failed
        if not self.log_data_end_of_data:
            pyotherside.send(["failed", "Device disconnected"])
        print("Device was disconnected", flush=True)
        # Cancel all tasks
        for task in asyncio.all_tasks():
            task.cancel()

    def handle_rx(self, _, data):
        if len(data) <= 0:
            print("Received empty data", flush=True)
        else:
            if data[0] == self.destination:
                if len(data) != 11:
                    print("Wrong data size", flush=True)
                else:
                    # Unpack binary data
                    # Header: Read command, Sensor, LOG_WRITE
                    # Payload: 4 bytes of timestamp and 4 bytes of value
                    dat = struct.unpack('>BBBII', data)
                    if dat[3] == 0xFFFFFFFF and dat[4] == 0xFFFFFFFF:
                        print("End of output received", flush=True)
                        # Send data to QML
                        pyotherside.send(self.received_data)
                        self.log_data_end_of_data = True
                    else:
                        # Gather data
                        self.received_data.append(dat)
                        # Send update to QML that we got data
                        self.data_received_amount += 1
                        pyotherside.send([
                                            "data_received_amount",
                                            self.data_received_amount
                                        ])

    async def read_log_data(self):
        print(f"Searching for Ruuvi {self.device_address}", flush=True)
        async with bleak.BleakClient(
                                    self.device_address,
                                    disconnected_callback=self.handle_disconnect,
                                    timeout=40
                                    ) as client:
            # Send update to QML that we are connected
            pyotherside.send(["connected"])
            print("Connected to Ruuvi, starting notify",
                  flush=True)
            await client.start_notify(UART_TX_CHAR_UUID, self.handle_rx)

            # Create tx_data
            # Data header: First byte is the sensor to be read (destination)
            # Second byte is source, and it can be any
            # Third byte is LOG_READ command
            tx_data = b''
            tx_data += bytes([self.destination])
            tx_data += bytes([self.destination])
            tx_data += bytes([LOG_READ])
            # Payload: Two 32-bit timestamps. First timestamp is current time,
            # and second time is the lower bound of log data
            tx_data += struct.pack('>I', int(time()))
            tx_data += struct.pack('>I', self.start_timestamp)

            # Write to NUS gatt charasteristic
            print(
                  f"Requesting log data starting from {self.start_timestamp}",
                  flush=True
                  )
            await client.write_gatt_char(UART_RX_CHAR_UUID, tx_data)
            while True:
                if self.log_data_end_of_data:
                    print(
                         "All log data received, closing connection",
                         flush=True)
                    client.close()
                    break
                await asyncio.sleep(1)

    def run(self, device_address, start_timestamp, sensor):
        # Clear the class attributes for this run
        self.received_data = ["data"]
        self.log_data_end_of_data = False
        self.data_received_amount = 0

        # Set the attributes for this run
        start_timestamp = int(start_timestamp)
        self.start_timestamp = start_timestamp
        self.device_address = device_address
        # Parse log type
        if sensor == "all":
            self.destination = ALL_SENSORS
        elif sensor == "temperature":
            self.destination = TEMPERATURE
        elif sensor == "humidity":
            self.destination = HUMIDITY
        else:
            self.destination = AIR_PRESSURE

        # Read the logs
        try:
            asyncio.run(self.read_log_data())
        except asyncio.CancelledError:
            # Ignore, task cancelled on device disconnect
            pass
        except bleak.exc.BleakDBusError as e:
            print(e)
            pyotherside.send(["failed", str(e)])
        except bleak.exc.BleakError as e:
            print(e)
            pyotherside.send(["failed", str(e)])
        except asyncio.exceptions.TimeoutError:
            pyotherside.send(["failed", "Could not find the device"])

    def get_logs(self, device_address, start_timestamp, sensor):
        if self.bgthread.is_alive():
            # Old run not finished yet, wait a bit and retry for 5 times
            i = 0
            while self.bgthread.is_alive():
                if i > 4:
                    print("Could not start new thread, exitting")
                    pyotherside.send(["failed", "Could not start new thread"])
                    return
                print("Could not start new thread, retrying")
                sleep(1)
                i += 1

        self.bgthread = threading.Thread(target=self.run,
                                         args=(
                                                device_address,
                                                start_timestamp,
                                                sensor
                                              )
                                         )
        self.bgthread.start()


ruuvi_tag_reader = RuuviTagReader()
