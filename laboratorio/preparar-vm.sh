#!/usr/bin/env bash
set -euo pipefail
nome='Guardiao-Antigolpe'
pasta_vms="$HOME/VirtualBox VMs"
disco="$pasta_vms/$nome/Servidor.vdi"
arquivo='/mnt/discoooolol'
iso="${ISO_WINDOWS:-$arquivo/faculdade/GS-CitizenTech-2026/Operating-Systems/Windows-Server-2022-Evaluation.iso}"
command -v VBoxManage >/dev/null || { echo 'Instale o VirtualBox antes de iniciar.' >&2; exit 1; }
if VBoxManage showvminfo "$nome" >/dev/null 2>&1; then
    VBoxManage showvminfo "$nome" --machinereadable | grep -E '^(name|VMState|CfgFile|"SATA-0-0")='
    exit 0
fi
[[ $(findmnt -n -o SOURCE -T "$HOME") == /dev/nvme* ]] || { echo 'Confira o NVMe para o disco ativo.' >&2; exit 1; }
if [[ $iso == "$arquivo/"* ]]; then
    [[ $(findmnt -n -o LABEL -M "$arquivo") == discoooolol ]] || { echo 'Confira o disco de arquivo.' >&2; exit 1; }
fi
[[ -r $iso ]] || { echo 'Informe a ISO do Windows Server em ISO_WINDOWS.' >&2; exit 1; }
[[ ! -e "$pasta_vms/$nome" ]] || { echo 'A pasta ja existe. Confira a VM antes de continuar.' >&2; exit 1; }
if [[ -n ${ISO_APLICACAO:-} && ! -r $ISO_APLICACAO ]]; then
    echo 'Confira ISO_APLICACAO.' >&2
    exit 1
fi
VBoxManage createvm --name "$nome" --ostype Windows2022_64 --basefolder "$pasta_vms" --register
VBoxManage modifyvm "$nome" --memory 4096 --cpus 2 --ioapic on --graphicscontroller vboxsvga --vram 64 --nic1 nat --boot1 disk --boot2 dvd
VBoxManage storagectl "$nome" --name SATA --add sata --controller IntelAhci --hostiocache on
VBoxManage createmedium disk --filename "$disco" --size 61440 --format VDI
VBoxManage storageattach "$nome" --storagectl SATA --port 0 --device 0 --type hdd --medium "$disco"
VBoxManage storageattach "$nome" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$iso"
if [[ -n ${ISO_APLICACAO:-} ]]; then
    VBoxManage storageattach "$nome" --storagectl SATA --port 2 --device 0 --type dvddrive --medium "$ISO_APLICACAO"
fi
VBoxManage modifyvm "$nome" --natpf1 'painel,tcp,127.0.0.1,18081,10.0.2.10,80'
