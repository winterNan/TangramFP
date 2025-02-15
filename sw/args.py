import argparse
from colorama import Fore, Style
import os
import sys
from os.path import dirname, abspath
sys.path.append((dirname(abspath(__file__))))

### config zone

class args:
    debug     = bool(os.environ.get('KACYDEBUG') == "Y")
    monkey    = os.environ.get('KACY')
    pw        = int(os.environ.get('KACYPW'))
    offset    = int(os.environ.get('KACYOFFSET'))
    # choose among 0x00 and 0x10
    tangram   = 0x10
    dumpon    = os.environ.get('KACYDUMPON') == "Y"
    chunksize = int(os.environ.get('KACYCHUNKSIZE'))
    ncore     = int(os.environ.get('KACYNUMWORKER'))


class config:

    def __init__(self, args):
        self.debug     = args.debug
        self.monkey    = args.monkey
        self.pw        = args.pw
        self.offset    = args.offset # thres1: pw+offset
        self.tangram   = args.tangram
        self.dumpon    = args.dumpon
        self.chunksize = args.chunksize
        self.ncore     = args.ncore
        self.mn = self.__makeMonkeyName()
        if self.tangram == 0x00:
            print(Fore.CYAN + "Multiplier enabled with config: " + \
                  Style.RESET_ALL,
                  self.mn,str(11-self.pw)+":"+str(self.pw))
        elif self.tangram == 0x10:
            print(Fore.CYAN + "Multiplier enabled with config: " + \
                  Style.RESET_ALL,
                  self.mn,"1:"+str(10-self.pw)+":"+str(self.pw))
        else:
            print("kacy config wrong")
            exit(-1)

    def __makeMonkeyName(self):
        if self.monkey == "":
            return "KACY OFF"
        elif self.monkey == "ORI":
            return "*"
        elif self.monkey == "1_X_Y":
            if self.tangram == 0x00:
                return "kacy%>(X:Y)"
            elif self.tangram == 0x10:
                return "kacy%>(1:X:Y)"
            else:
                print("kacy config wrong")
                exit(-1)
        else:
            return "invalid"

config = config(args)
