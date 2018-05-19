# metro-extracts
Extracts of OpenStreetMap data.

## Running

I set up a new AWS EC2 instance of type `m5.4xlarge` in a Spot request. I used the default maximum bid. The script in this repo assumes the Ubuntu 16.04 AMI. I also attached 300GB of Standard IO volume and picked an SSH key I had access to.

Once that instance was up, I ssh'd to it and ran the following commands:

```
curl -L https://github.com/nextzen/metro-extracts/archive/master.tar.gz | tar xz
metro-extracts-master/run.sh
```
