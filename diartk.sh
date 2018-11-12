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
audio_dir=$BASEDIR/$1
trs_format=$2


### Other variables specific to this script
# create temp dir
workdir=$audio_dir/temp/diartk
mkdir -p $workdir

### SCRIPT STARTS
cd $BASEDIR/repos/ib_diarization_toolkit


# Check audio_dir to see if empty or if contains empty wav
bash $UTILS/check_folder.sh $audio_dir


for fin in `ls $audio_dir/*.wav`; do
    filename=$(basename "$fin")
    basename="${filename%.*}"
    echo "treating $basename"
    
    featfile=$workdir/$basename.fea
    scpfile=$workdir/$basename.scp
    
    # first-first convert RTTM to DiarTK's version of a .scp file
    # SCP format:
    #   <basename>_<start>_<end>=<filename>[start,end]
    # RTTM format:
    #   Type file chan tbeg tdur ortho stype name conf Slat
    # math: convert RTTM seconds to HTK (10ms default) frames = multiply by 100
    case $trs_format in
      "ldcSad")
       sys="ldcSad"
       $conda_dir/python $UTILS/rttm2scp.py $audio_dir/ldcSad_${basename}.rttm $scpfile
      ;;
     "noisemesSad")
       sys="noisemesSad"
       $conda_dir/python $UTILS/rttm2scp.py $audio_dir/noisemes_sad_${basename}.rttm $scpfile
      ;;
      "tocomboSad")
       sys="tocomboSad"
        $conda_dir/python $UTILS/rttm2scp.py $audio_dir/tocombo_sad_${basename}.rttm $scpfile
      ;;
      "opensmileSad")
       sys="opensmileSad"
        $conda_dir/python $UTILS/rttm2scp.py $audio_dir/opensmile_sad_${basename}.rttm $scpfile
      ;;
      "textgrid") 
       sys="goldSad"
       $conda_dir/python /home$UTILS/textgrid2rttm.py $audio_dir/${basename}.TextGrid $workdir/${basename}.rttm
       $conda_dir/python $UTILS/rttm2scp.py $workdir/${basename}.rttm $scpfile
       rm $workdir/$basename.rttm
      ;;
      "eaf")
       sys="goldSad"
       $conda_dir/python /home$UTILS/elan2rttm.py $audio_dir/${basename}.eaf $workdir/${basename}.rttm
       $conda_dir/python $UTILS/rttm2scp.py $workdir/${basename}.rttm $scpfile
       rm $workdir/$basename.rttm
      ;;
      "rttm")
       sys="goldSad"
       # Since some reference rttm files are spaced rather than tabbed, we need to
       # tab them before using them.
       cp $audio_dir/${basename}.rttm $workdir/${basename}.rttm
       sed -i 's/ \+/\t/g' $workdir//${basename}.rttm
       $conda_dir/python $UTILS/rttm2scp.py $workdir/${basename}.rttm $scpfile
      ;;
      *)
       echo "ERROR: please choose SAD system between:"
       echo "  ldcSad"
       echo "  noisemesSad"
       echo "  tocomboSad"
       echo "  opensmileSad"
       echo "  textgrid"
       echo "  eaf"
       echo "  rttm"
       echo "Now exiting..."
       exit 1
      ;;
    esac
   
    # don't process files with empty transcription
    if [ -s $scpfile ]; then 
        # first generate HTK features
        HCopy -T 2 -C htkconfig $fin $featfile
        
        # next run DiarTK
        scripts/run.diarizeme.sh $featfile $scpfile $workdir $basename
        
        # print results
        #cat $workdir/$basename.out
        cp $workdir/$basename.rttm $audio_dir/diartk_${sys}_${basename}.rttm
    fi
    if [ ! -s $audio_dir/diartk_${sys}_${basename}.rttm ]; then
        # if diarization failed, still write an empty file...
        touch $audio_dir/diartk_${sys}_${basename}.rttm
    fi



done

# Delete temporary folder
rm -rf $workdir
