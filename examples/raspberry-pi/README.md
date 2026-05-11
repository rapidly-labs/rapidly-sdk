# Raspberry Pi setup for the Rapidly Engine

1. Download and run the Raspberry Pi Imager:
   * Follow the instructions on [Raspberry Pi website](https://www.raspberrypi.com/software/)
   
2. Select "Raspberry Pi OS with desktop and recommended software" (64 bit) and install it on an empty SD card.

3. Select Yes to "Would you like to apply OS customization settings?", then click "Edit settings":
   * Choose user credentials and WiFi settings
   * Write the image to the SD card

4. Login to the Raspberry Pi and:
   * Setup git: [Github website](https://docs.github.com/en/get-started/getting-started-with-git/set-up-git)

5. Fetch the Rapidly SDK source:
   * `git clone <public-sdk-repo-url>` <!-- TODO launch-day: replace with the published Rapidly SDK repo URL -->

6. Build the engine and benchmark program:
   * `cd <repo-root>/engine`
   * `sh build-linux.sh`

7. Run the benchmark:
   * `cd build_linux/Bin`
   * `./Benchmark`

And you're good to go.
