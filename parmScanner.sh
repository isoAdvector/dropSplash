#!/bin/bash

#Make a sequence of copies of baseCase and change one or more parameters in the
#setup files of each case

#Settings

baseCase=${1:-baseCase_v3}

scanDir=${2:-RadiusViscosityScan}

if [ ! -d "$scanDir" ];
then
    mkdir $scanDir
    cp -r $baseCase $scanDir
fi

parm1File="modelParms"
parm1Name=dropRadius
parm1ShortName=R
parm1Range=($(tail +2 testMatrix | cut -d' ' -f1))
#echo $parm1Range

for m in ${!parm1Range[*]}
do
    parm1=${parm1Range[$m]}
    echo $parm1
done

parm2File="constant/transportProperties"
parm2Name=water.nu
parm2ShortName=nu
parm2Range=($(tail +2 testMatrix | cut -d' ' -f2))
#echo $parm2Range

cd $scanDir

##########################

echo "=========================================" >> README
echo "Parameter scan generated with scanner script" >> README
echo "Date: " $(date) >> README
echo "Base case: $baseCase" >> README
echo "Parameters: $parm1Name    $parm2Name" >> README
echo "=========================================" >> README
echo "Case    $parm1Name    $parm2Name" >> README

for m in ${!parm1Range[*]}
do
    parm1=${parm1Range[$m]}
    parm2=${parm2Range[$m]}
    caseName=$parm1ShortName$parm1$parm2ShortName$parm2
    if [ "${1}" = "run" ];
    then
        cd ${caseName}
        ./Allrun &
        cd ..
    elif [ ! -d "$caseName" ];
    then
        cp -r ../$baseCase $caseName
        foamDictionary -entry "${parm1Name}" -set "${parm1}" ${caseName}/${parm1File}
#        sed -i "s/${parm1Name}\s*=.*/${parm1Name}=${parm1}/" ${caseName}/${parm1File}
        foamDictionary -entry "${parm2Name}" -set "${parm2}" ${caseName}/${parm2File}
        echo "$caseName:    $parm1    $parm2" >> README
    else
        echo "Directory $caseName already exists - not recreated."
    fi
done

echo "=========================================" >> README