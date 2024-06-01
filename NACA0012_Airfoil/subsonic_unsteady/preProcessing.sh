#!/bin/bash

# Check if the OpenFOAM enviroments are loaded
if [ -z "$WM_PROJECT" ]; then
  echo "OpenFOAM environment not found, forgot to source the OpenFOAM bashrc?"
  exit
fi

# generate mesh
echo "Generating mesh.."
python genAirFoilMesh.py &> logMeshGeneration.txt
plot3dToFoam -noBlank volumeMesh.xyz >> logMeshGeneration.txt
autoPatch 30 -overwrite >> logMeshGeneration.txt
createPatch -overwrite >> logMeshGeneration.txt
renumberMesh -overwrite >> logMeshGeneration.txt
echo "Generating mesh.. Done!"

# copy initial and boundary condition files
cp -r 0_orig 0

# run simpleFoam
cp -r system/controlDict_rhosimple system/controlDict
cp -r system/fvSchemes_rhosimple system/fvSchemes
cp -r system/fvSolution_rhosimple system/fvSolution
potentialFoam
rm -rf 0/phi*
mpirun -np 4 python runPrimalRhoSimple.py

# reconstruct the simpleFoam fields
reconstructPar
rm -rf processor*
rm -rf 0
mv 500 0
rm -rf 0/uniform 0/polyMesh

# run the pimpleFoam primal to get equilibrium initial fields
cp -r system/controlDict_rhopimple_long system/controlDict
cp -r system/fvSchemes_rhopimple system/fvSchemes
cp -r system/fvSolution_rhopimple system/fvSolution
mpirun -np 4 python runScript_v2.py --task=runPrimal
reconstructPar -latestTime
rm -rf processor*
rm -rf 0
mv 5 0
rm -rf 0/uniform 0/polyMesh
cp -r system/controlDict_rhopimple system/controlDict
