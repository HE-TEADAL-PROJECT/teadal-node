package main

import (
	"os"
	"strconv"
	"strings"

	apiv1 "k8s.io/api/core/v1"
	resource "k8s.io/apimachinery/pkg/api/resource"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"sigs.k8s.io/yaml"
)

type PVKustomize struct {
	APIVersion string   `json:"apiVersion,omitempty"`
	Kind       string   `json:"kind,omitempty"`
	Resources  []string `json:"resources,omitempty"`
}

func createPV(storage string, node_name string, volume_name string, path string) apiv1.PersistentVolume {
	return apiv1.PersistentVolume{
		TypeMeta: v1.TypeMeta{
			APIVersion: "v1",
			Kind:       "PersistentVolume",
		},
		ObjectMeta: v1.ObjectMeta{
			Name: volume_name},
		Spec: apiv1.PersistentVolumeSpec{
			Capacity: apiv1.ResourceList{
				apiv1.ResourceName(apiv1.ResourceStorage): resource.MustParse(storage + "Gi")},
			AccessModes:                   []apiv1.PersistentVolumeAccessMode{apiv1.ReadWriteOnce},
			PersistentVolumeReclaimPolicy: apiv1.PersistentVolumeReclaimPolicy(apiv1.PersistentVolumeReclaimRetain),
			StorageClassName:              "local-storage",
			PersistentVolumeSource:        apiv1.PersistentVolumeSource{Local: &apiv1.LocalVolumeSource{Path: path}},
			NodeAffinity: &apiv1.VolumeNodeAffinity{
				Required: &apiv1.NodeSelector{
					NodeSelectorTerms: []apiv1.NodeSelectorTerm{
						{
							MatchExpressions: []apiv1.NodeSelectorRequirement{
								{
									Key:      "kubernetes.io/hostname",
									Operator: apiv1.NodeSelectorOpIn,
									Values:   []string{node_name},
								},
							},
						},
					},
				},
			},
		},
	}
}

func writePV(index int, storage string, node_name string) error {
	i_to_string := strconv.Itoa(index)
	volume_name := node_name + "-" + i_to_string
	path := "/mnt/data/d" + i_to_string
	new_pv := createPV(storage, node_name, volume_name, path)

	file_name := node_name + "/" + node_name + "-" + i_to_string + ".yaml"
	if new_pv_yaml, err := yaml.Marshal(new_pv); err != nil {
		return err
	} else {
		return os.WriteFile(file_name, new_pv_yaml, 0644)
	}
}

func writeKustomization(node_name string) error {
	if _, err := os.Stat(node_name); os.IsNotExist(err) {
		return err
	}

	files, _ := os.ReadDir(node_name)

	var resources []string

	for _, file := range files {
		if strings.Contains(file.Name(), node_name) {
			resources = append(resources, file.Name())
		}
	}

	var kustomization PVKustomize = PVKustomize{}
	kustomization.APIVersion = "kustomize.config.k8s.io/v1beta1"
	kustomization.Kind = "Kustomization"
	kustomization.Resources = resources
	filename := node_name + "/" + "kustomization.yaml"

	if new_kustomization_yaml, err := yaml.Marshal(kustomization); err != nil {
		return err
	} else {
		return os.WriteFile(filename, new_kustomization_yaml, 0644)
	}

}
