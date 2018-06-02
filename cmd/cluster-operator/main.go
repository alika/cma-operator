package main

import (
	"flag"
	"strings"
	"sync"

	"github.com/samsung-cnct/cma-operator/pkg/util"
	"github.com/samsung-cnct/cma-operator/pkg/util/k8sutil"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"

	"github.com/juju/loggo"
	ccworkqueue "github.com/samsung-cnct/cma-operator/pkg/controllers/kraken-cluster"
	"github.com/samsung-cnct/cma-operator/pkg/controllers/sdsapplication"
	"github.com/samsung-cnct/cma-operator/pkg/controllers/sds-cluster"
	"github.com/samsung-cnct/cma-operator/pkg/controllers/sds-package-manager"
	"github.com/samsung-cnct/cma-operator/pkg/util/cma"
	apiextensionsclient "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset"
	"k8s.io/client-go/rest"
)

var (
	logger loggo.Logger
	config *rest.Config
)

func main() {
	var err error
	logger := util.GetModuleLogger("cmd.cma-operator", loggo.INFO)
	viperInit()

	// get flags
	portNumber := viper.GetInt("port")
	kubeconfigLocation := viper.GetString("kubeconfig")

	// Debug for now
	logger.Infof("Parsed Variables: \n  Port: %d \n  Kubeconfig: %s", portNumber, kubeconfigLocation)

	k8sutil.KubeConfigLocation = kubeconfigLocation
	k8sutil.DefaultConfig, err = k8sutil.GenerateKubernetesConfig()

	if err != nil {
		logger.Infof("Was unable to generate a valid kubernetes default config, some functionality may be broken.  Error was %v", err)
	}

	// Install the CMA SDSCluster CRD
	k8sutil.CreateCRD(apiextensionsclient.NewForConfigOrDie(k8sutil.DefaultConfig), cma.GenerateSDSClusterCRD())
	// Install the CMA SDSPackageManager CRD
	k8sutil.CreateCRD(apiextensionsclient.NewForConfigOrDie(k8sutil.DefaultConfig), cma.GenerateSDSPackageManagerCRD())
	// Install the CMA SDSApplication CRD
	k8sutil.CreateCRD(apiextensionsclient.NewForConfigOrDie(k8sutil.DefaultConfig), cma.GenerateSDSApplicationCRD())

	var wg sync.WaitGroup
	stop := make(chan struct{})

	logger.Infof("Starting the SDSCluster Controller")
	sdsClusterController := sds_cluster.NewSDSClusterController(nil)
	wg.Add(1)
	go func() {
		defer wg.Done()
		sdsClusterController.Run(3, stop)
	}()

	sdsPackageManagerController := sds_package_manager.NewSDSPackageManagerController(nil)
	// Start the SDSPackageManager Controller
	wg.Add(1)
	go func() {
		defer wg.Done()
		sdsPackageManagerController.Run(3, stop)
	}()
	// TODO: Start the SDSApplication Controller

	sdsApplicationController := sdsapplication.NewSDSApplicationController(nil)
	// Start the SDSPackageManager Controller
	wg.Add(1)
	go func() {
		defer wg.Done()
		sdsApplicationController.Run(3, stop)
	}()

	logger.Infof("Starting KrakenCluster Watcher")
	wg.Add(1)
	go func() {
		defer wg.Done()
		ccworkqueue.ListenToKrakenClusterChanges(nil)
	}()

	<-stop
	logger.Infof("Wating for controllers to shut down gracefully")
	wg.Wait()
}

func viperInit() {
	viper.SetEnvPrefix("clustermanagerapi")
	replacer := strings.NewReplacer("-", "_")
	viper.SetEnvKeyReplacer(replacer)

	// using standard library "flag" package
	flag.Int("port", 9050, "Port to listen on")
	flag.String("kubeconfig", "", "Location of kubeconfig file")

	pflag.CommandLine.AddGoFlagSet(flag.CommandLine)
	pflag.Parse()
	viper.BindPFlags(pflag.CommandLine)

	viper.AutomaticEnv()
}
