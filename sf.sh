echo -e "Uploading on Sourceforge"
# Sourceforge
scp *.zip skyy123@frs.sourceforge.net:/home/frs/project/risingosbyskyy/QuantumPrjkt/

sleep 1
echo -e "Upload succesfully"

sleep 1
echo -e "Cleaning Up"

# Clean All
rm -rvf *.zip
 
sleep 1
echo -e "Clean succesfully"
