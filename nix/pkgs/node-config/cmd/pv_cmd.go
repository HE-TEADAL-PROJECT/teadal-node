package main

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/urfave/cli/v2"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func PvCmd(ctx *cli.Context) error {
	var err error

	if ctx.Args().Len() < 1 {
		err = errors.New("no arguments were passed")
		return err
	}

	list_of_pvs := ctx.Args().Slice()

	node_list, err := clientset.CoreV1().Nodes().List(ctx.Context, v1.ListOptions{})

	if err != nil {
		return err
	}

	if len(node_list.Items) < 1 {
		err = errors.New("no nodes could be found")
		return err
	}

	// Assuming it is a single node deployment
	node_name := node_list.Items[0].Name
	index := 1

	for _, pvs := range list_of_pvs {
		pvs_values := strings.Split(pvs, ":")
		storage := pvs_values[1]
		nr_of_pvs, err := strconv.Atoi(pvs_values[0])

		if err != nil {
			return err
		}

		if _, err := os.Stat(node_name); os.IsNotExist(err) {
			if err := os.Mkdir(node_name, os.ModePerm); err != nil {
				return err
			}
		}

		for i := 1; i <= nr_of_pvs; i++ {
			if err := writePV(index, storage, node_name); err != nil {
				return err
			}
			index++
		}
	}
	writeKustomization(node_name)

	return err
}

func PrintHelp(ctx *cli.Context) error {
	fmt.Printf("TEADAL LOCAL PV GENERATOR\n")
	fmt.Printf("To use, pass a space-separated, list of tuples with your requirements\n")
	fmt.Printf("For example, for 2 10GB PV and 1 20GB PV: \n")
	fmt.Printf("pvlocalgen 2:10 1:20\n")
	return nil
}
