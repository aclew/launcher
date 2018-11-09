#!/bin/bash
# Launcher onset routine
source ~/.bashrc
SCRIPT=$(readlink -f $0)
BASEDIR=`dirname $(dirname $SCRIPT )`
conda_dir=$BASEDIR/anaconda/bin
REPOS=$BASEDIR/repos
UTILS=$BASEDIR/utils
# end of launcher onset routine


### Read in variables from user
audio_dir=$BASEDIR/1
trs_format=$2


### Other variables speicfic to this script
# create temp dir
workdir=$audio_dir/temp/tocomboSad
mkdir -p $workdir
TOCOMBOSADDIR=$REPOS/To-Combo-SAD
MCR=/usr/local/MATLAB/MATLAB_Runtime/v93

### SCRIPT STARTS

if [ $# -ne 1 ]; then
  echo "Usage: tocombo_sad.sh <dirname>"
  echo "where dirname is a folder on the host"
  echo "containing the wav files (/vagrant/dirname/ in the VM)"
  exit 1
fi

filename=$(basename "$audio_dir")
dirname=$(dirname "$audio_dir")
extension="${filename##*.}"
basename="${filename%.*}"

# Check audio_dir to see if empty or if contains empty wav
bash $BASEDIR/check_folder.sh $audio_dir

# let's get our bearings: set CWD to path of ToComboSAD
cd $TOCOMBOSADDIR

mkdir -p $workdir/feat
rm -f $workdir/filelist.txt
touch $workdir/filelist.txt

# create temp dir to store audio files with 1 channels, if needed (i.e. if audio to treat has 2 or more channels.)
# Indeed, To Combo Sad Fails when there are more than 1 channels.
for f in $audio_dir/*.wav; do
   # Check if audio has 1 channel or more. If it has more, use sox to create a temp audio file w/ 1 channel.
   n_chan=$(soxi $f | grep Channels | cut -d ':' -f 2)
   if [[ $n_chan -gt 1 ]]; then 
       base=$(basename $f)
       sox -c $n_chan $f -c 1 $workdir/$base
       f=$workdir/$base
   fi

   echo $f >> $workdir/filelist.txt

done
echo "finished"

export LD_LIBRARY_PATH=$MCR/runtime/glnxa64:$MCR/bin/glnxa64:$MCR/sys/os/glnxa64:

./run_get_TOcomboSAD_output_v3.sh $MCR $workdir/filelist.txt 0 0.5 $TOCOMBOSADDIR/UBMnodct256Hub5.txt

# Retrieve the outputs from the temp folder
mv $workdir/*ToCombo.txt $audio_dir

#convert to rttms
for f in $audio_dir/*.ToCombo.txt; do
  bn=`basename $f .wav.ToCombo.txt`
  python $TOCOMBOSADDIR/tocombo2rttm.py $f $bn > $audio_dir/tocombo_sad_$bn.rttm
done

# Delete temporary folder
rm -rf $workdir