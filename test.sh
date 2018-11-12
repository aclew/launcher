#!/bin/bash 
#
# This script tests numerous tools
# from a downloaded 5 minute section of the HomeBank VanDam daylong audio sample
# ("ACLEW Starter" data)

# Launcher onset routine
source ~/.bashrc
SCRIPT=$(readlink -f $0)
BASEDIR=`dirname $(dirname $SCRIPT )`
conda_dir=$BASEDIR/anaconda/bin
REPOS=$BASEDIR/repos
UTILS=$BASEDIR/utils
NOHOME=` echo $BASEDIR | sed "s/\/home//"`
# end of launcher onset routine


### Read in variables from user
#none


### Other variables specific to this script
# create temp dir
audio_dir=$NOHOME/data/
workdir=$audio_dir/temp/test/
mkdir -p $workdir

# this doesn't work because .bashrc exits immediately if not running interactively
#source $BASEDIR/.bashrc -i
# instead:
export PATH=$BASEDIR/anaconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
LD_LIBRARY_PATH="/usr/local/MATLAB/MATLAB_Runtime/v93/runtime/glnxa64:/usr/local/MATLAB/MATLAB_Runtime/v93/bin/glnxa64:/usr/local/MATLAB/MATLAB_Runtime/v93/sys/os/glnxa64:$LD_LIBRARY_PATH"

# Paths to Tools
LDC_SAD_DIR=$REPOS/ldc_sad_hmm
OPENSATDIR=$REPOS/OpenSAT     # noisemes
OPENSMILEDIR=$REPOS/openSMILE-2.1.0/
TOCOMBOSAD=$REPOS/To-Combo-SAD
DIARTKDIR=$REPOS/ib_diarization_toolkit
#TALNETDIR=$REPOS/TALNet
DSCOREDIR=$REPOS/dscore
YUNITATORDIR=$REPOS/Yunitator

### SCRIPT STARTS
FAILURES=false

echo "Starting tests"
echo "Downloading test audio..."

cd $audio_dir
# get transcript
wget -q -N https://homebank.talkbank.org/data/Public/VanDam-Daylong.zip
unzip -q -o VanDam-Daylong.zip

# This is the working directory for the tests; right beside the input
cd $audio_dir/VanDam-Daylong/BN32/
# Get daylong recording from the web
wget -q -N https://media.talkbank.org/homebank/Public/VanDam-Daylong/BN32/BN32_010007.mp3

WORKDIR=`pwd`
DATADIR=$audio_dir/VanDam-Daylong/BN32  # relative to /vagrant, used by launcher scripts
BASE=BN32_010007 # base filename for test input file, minus .wav or .rttm suffix
BASETEST=${BASE}_test
START=2513 # 41:53 in seconds
STOP=2813  # 46:53 in seconds

# get 5 minute subset of audio
sox $BASE.mp3 $BASETEST.wav trim $START 5:00 >& /dev/null 2>1

# convert CHA to reliable STM
$UTILS/chat2stm.sh $BASE.cha > $BASE.stm 2>/dev/null
# convert STM to RTTM as e.g. BN32_010007.rttm
# shift audio offsets to be 0-relative
cat $BASE.stm | awk -v start=$START -v stop=$STOP -v file=$BASE -e '{if (($4 > start) && ($4 < stop)) print "SPEAKER",file,"1",($4 - start),($5 - $4),"<NA>","<NA>","<NA>","<NA>","<NA>" }' > $BASETEST.rttm
TEST_RTTM=$WORKDIR/$BASETEST.rttm
TEST_WAV=$WORKDIR/$BASETEST.wav


# Check for HTK
echo "Checking for HTK..."
if [ -s /usr/local/bin/HCopy ]; then
    echo "HTK is installed."
else
    echo "   HTK missing; did you first download HTK-3.4.1 from http://htk.eng.cam.ac.uk/download.shtml"
    echo "   and rename it to HTK.tar.gz ?"
fi

# First test in ldc_sad_hmm
echo "Testing ldcSad..."
if [ -s $LDC_SAD_DIR/perform_sad.py ]; then
    cd $LDC_SAD_DIR
    TESTDIR=$WORKDIR/ldcSad-test
    rm -rf $TESTDIR; mkdir -p $TESTDIR
    $conda_dir/python perform_sad.py -L $TESTDIR $TEST_WAV > $TESTDIR/ldcSad.log 2>&1 || { echo "   ldcSad failed - dependencies"; FAILURES=true;}
    # convert output to rttm, for diartk.
    grep ' speech' $TESTDIR/$BASETEST.lab | awk -v fname=$BASE '{print "SPEAKER" " " fname " " 1  " " $1  " " $2-$1 " " "<NA>" " " "<NA>"  " " $3  " "  "<NA>"}'   > $TESTDIR/$BASETEST.rttm
    if [ -s $TESTDIR/$BASETEST.rttm ]; then
	echo "ldcSad passed the test."
    else
	FAILURES=true
	echo "   ldcSad failed - no output RTTM"
    fi
else
    echo "   ldcSadfailed because the code for ldcSad is missing. This is normal, as we are still awaiting the official release!"
fi


# now test Noisemes
echo "Testing noisemesSad..."
cd $OPENSATDIR
TESTDIR=$WORKDIR/noisemes-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
ln -fs $TEST_WAV $TESTDIR
./runDiarNoisemes.sh $TESTDIR > $TESTDIR/nosiemes-test.log 2>&1 || (echo "noisemesSad failed - dependencies" && FAILURES=true)
cp $TESTDIR/hyp_sum/$BASETEST.rttm $TESTDIR

if [ -s $TESTDIR/hyp_sum/$BASETEST.rttm ]; then
    echo "noisemesSad passed the test."
else
    FAILURES=true
    echo "   noisemesSad failed - no RTTM output"
fi
# clean up
rm -rf $OPENSATDIR/SSSF/data/feature $OPENSATDIR/SSSF/data/hyp


# now test OPENSMILEDIR
echo "Testing opensmileSad..."
cd $OPENSMILEDIR
TESTDIR=$WORKDIR/opensmile-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
ln -fs $TEST_WAV $TESTDIR



$BASEDIR/launcher/opensmileSad.sh $DATADIR/opensmile-test >$TESTDIR/opensmile-test.log || { echo "   opensmileSad failed - dependencies"; FAILURES=true;}

if [ -s $TESTDIR/opensmile_sad_$BASETEST.rttm ]; then
    echo "opensmileSad passed the test."
else
    FAILURES=true
    echo "   opensmileSad failed - no RTTM output"
fi

# now test TOCOMBOSAD
echo "Testing tocomboSad..."
cd $TOCOMBOSAD
TESTDIR=$WORKDIR/tocombo_sad-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
ln -fs $TEST_WAV $TESTDIR
$BASEDIR/launcher/tocomboSad.sh $DATADIR/tocombo_sad-test > $TESTDIR/tocombo_sad_test.log 2>&1 || { echo "   tocomboSad failed - dependencies"; FAILURES=true;}

if [ -s $TESTDIR/tocombo_sad_$BASETEST.rttm ]; then
    echo "tocomboSad passed the test."
else
    FAILURES=true
    echo "   tocomboSad failed - no output RTTM"
fi


# finally test DIARTK
echo "Testing diartk..."
cd $DIARTKDIR
TESTDIR=$WORKDIR/diartk-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
# run like the wind
./run-rttm.sh $TEST_WAV $TEST_RTTM $TESTDIR > $TESTDIR/diartk-test.log 2>&1
if grep -q "command not found" $TESTDIR/diartk-test.log; then
    echo "   diartk failed - dependencies (probably HTK)"
    FAILURES=true
else
    if [ -s $TESTDIR/$BASETEST.rttm ]; then
	echo "diartk passed the test."
    else
	FAILURES=true
	echo "   diartk failed - no output RTTM"
    fi
fi

# finally test Yunitator
echo "Testing yunitator..."
cd $YUNITATORDIR
TESTDIR=$WORKDIR/yunitator-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
ln -fs $TEST_WAV $TESTDIR
# let 'er rip
./runYunitator.sh $TESTDIR/$BASETEST.wav > $TESTDIR/yunitator-test.log 2>&1 || { echo "   yunitator failed - dependencies"; FAILURES=true;}
if [ -s $TESTDIR/Yunitemp/$BASETEST.rttm ]; then
    echo "yunitator passed the test."
else
    FAILURES=true
    echo "   yunitator failed - no output RTTM"
fi


# Test DSCORE
echo "Testing evalDiar..."
cd $DSCOREDIR
TESTDIR=$WORKDIR/dscore-test
rm -rf $TESTDIR; mkdir -p $TESTDIR
cp -r test_ref test_sys $TESTDIR
rm -f test.df
python score_batch.py $TESTDIR/test.df $TESTDIR/test_ref $TESTDIR/test_sys > $TESTDIR/dscore-test.log ||  { echo "   Dscore failed - dependencies"; FAILURES=true;}
if [ -s $TESTDIR/test.df ]; then
    echo "evalDiar passed the test."
else
    echo "   evalDiar failed the test - output does not match expected"
    FAILURES=true
fi


# testing LDC evalSAD (on opensmile)
echo "Testing evalSad"

if [ -d $LDC_SAD_DIR ]; then
    cd $LDC_SAD_DIR
    TESTDIR=$WORKDIR/opensmile-test
    cp $WORKDIR/$BASETEST.rttm $TESTDIR
    $BASEDIR/launcher/eval.sh $DATADIR/opensmile-test opensmile > $WORKDIR/ldcSad-test/ldc_evalSAD.log 2>&1 || { echo "   LDC evalSAD failed - dependencies"; FAILURES=true;}
    if [ -s $TESTDIR/opensmile_sad_eval.df ]; then
	echo "evalSad passed the test"
    else
	echo "   evalSad failed - no output .df"
	FAILURES=true
    fi
else
    echo "   evalSad failed because the code for ldcSad (on which it depends) is missing. This is normal, as we are still awaiting the official release!"
    FAILURES=true
fi


# test finished
if $FAILURES; then
    echo "Some tools did not pass the test, but you can still use others"
else
    echo "Congratulations, everything is OK!"
fi

# results
echo "RESULTS:"
for f in $DATADIR/*-test/*.rttm; do $UTILS/sum-rttm.sh $f; done
echo "Diarization score:"
cat $DATADIR/dscore-test/test.df
echo "Speech activity detection score:"
cat $TESTDIR/opensmile_sad_eval.df
