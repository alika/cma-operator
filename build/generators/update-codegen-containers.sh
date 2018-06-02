#!/usr/bin/env bash

# Setting some variables up here
THIS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_HOME=${THIS_DIRECTORY}/../../
PACKAGE_NAME=github.com/samsung-cnct/cma-operator
PACKAGE_VIRTUAL=/go/src/${PACKAGE_NAME}
K8S_CODE_GEN=quay.io/venezia/k8s-code-generator:v0.2.0
API_PACKAGE=cma/v1alpha1
GENERATED_CODE_HOME=pkg/generated/cma/client

echo "Removing old generated code"
rm -rf ${PACKAGE_HOME}/${GENERATED_CODE_HOME}
mkdir -p ${PACKAGE_HOME}/${GENERATED_CODE_HOME}

# Creating the deep copy object
echo "Creating the deep copy object in ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} ... "
docker run --rm=true -w $PACKAGE_VIRTUAL -v ${PACKAGE_HOME}:${PACKAGE_VIRTUAL} $K8S_CODE_GEN deepcopy-gen \
       --input-dirs ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} -h ${PACKAGE_VIRTUAL}/build/generators/custom-boilerplate.go.txt
printf ".... done creating deep copy object\n\n"

# Creating the openapi (validation) meta information
echo "Creating the openapi validation object in ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} ... "
docker run --rm=true -w $PACKAGE_VIRTUAL -v ${PACKAGE_HOME}:${PACKAGE_VIRTUAL} $K8S_CODE_GEN openapi-gen \
       -i ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE},k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/api/core/v1 \
       -p ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} -h ${PACKAGE_VIRTUAL}/build/generators/custom-boilerplate.go.txt
printf ".... done creating openapi validation object\n\n"

# Creating the clientset
echo "Creating the clientset in ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/clientset ... "
docker run --rm=true -w $PACKAGE_VIRTUAL -v ${PACKAGE_HOME}:${PACKAGE_VIRTUAL} $K8S_CODE_GEN client-gen \
       -p ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/clientset --input-base ${PACKAGE_NAME}/pkg/apis --input $API_PACKAGE -n versioned \
       -h ${PACKAGE_VIRTUAL}/build/generators/custom-boilerplate.go.txt
printf ".... done creating the clientset\n\n"

# Creating the lister
echo "Creating the lister in ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/listers ... "
docker run --rm=true -w $PACKAGE_VIRTUAL -v ${PACKAGE_HOME}:${PACKAGE_VIRTUAL} $K8S_CODE_GEN lister-gen \
       -p ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/listers --input-dirs ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} \
       -h ${PACKAGE_VIRTUAL}/build/generators/custom-boilerplate.go.txt
printf ".... done creating the lister\n\n"

# Creating the informer
echo "Creating the informer in ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/informers ... "
docker run --rm=true -w $PACKAGE_VIRTUAL -v ${PACKAGE_HOME}:${PACKAGE_VIRTUAL} $K8S_CODE_GEN informer-gen \
       -p ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/informers --input-dirs ${PACKAGE_NAME}/pkg/apis/${API_PACKAGE} \
       --versioned-clientset-package ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/clientset/versioned --listers-package ${PACKAGE_NAME}/${GENERATED_CODE_HOME}/listers \
       -h ${PACKAGE_VIRTUAL}/build/generators/custom-boilerplate.go.txt
printf ".... done creating the informer\n\n"
