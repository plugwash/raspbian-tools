#/bin/bash
for filename in *.dsc *.tar.* *.diff.*
do
  echo $filename
  if [ ${filename:0:3} == lib ]
  then
    firstdir=${filename:0:4}
  else
    firstdir=${filename:0:1}
  fi
  seconddir=`expr "$filename" : '\([^_]*\)'`
  mkdir -p pool/main/$firstdir/$seconddir/
  mv $filename pool/main/$firstdir/$seconddir/
done