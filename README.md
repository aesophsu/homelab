# homelab
homelab use nixos

1. 获取root权限
  passwd nixos
  ssh nixos@10.0.0.5
  sudo -s

  * 目的： 以root用户身份执行后续命令，拥有最高权限。
    
2. 查看磁盘信息
  lsblk

  * 目的： 列出系统中所有块设备（如硬盘、U盘），查看磁盘名称、分区等信息。
    
3. 分区磁盘
  fdisk /dev/sda

* 目的： 对指定磁盘（/dev/sda）进行分区。
  
* 详细操作：
    * g: 使用交互式模式。
    * n: 创建新的分区。
        * t: 设置分区类型。
            * 1: FAT32（boot分区）。
            * 19: LVM（swap分区）。
            * 20: Linux Ext4（根分区）。
* 分区示例：
    * 创建boot分区：512MB，FAT32格式。
    * 创建swap分区：4096MB，swap格式。
    * 创建根分区：剩余空间，Ext4格式。
      
4. 格式化分区
  mkfs.fat /dev/sda1
  mkswap /dev/sda2
  swapon /dev/sda2
  mkfs.ext4 /dev/sda3

  * 目的： 对各个分区进行格式化。
    * mkfs.fat: 格式化为FAT32格式。
    * mkswap: 格式化为swap分区。
    * swapon: 激活swap分区。
    * mkfs.ext4: 格式化为Ext4格式。
      
5. 挂载分区
  mount /dev/sda3 /mnt
  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
  cd /mnt

  * 目的： 将分区挂载到临时目录/mnt下，方便后续操作。
    * mount /dev/sda3 /mnt: 将根分区挂载到/mnt。
    * mkdir /mnt/boot: 创建boot分区目录。
    * mount /dev/sda1 /mnt/boot: 将boot分区挂载到/mnt/boot。
    * cd /mnt: 进入挂载点。
      
6. 生成配置文件
  nixos-generate-config --root /mnt/

  * 目的： 在挂载点生成NixOS的配置文件
    
7. 编辑配置文件
  nano /mnt/etc/nixos/configuration.nix
    新增：
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      users.users.jacky = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
      };
      services.openssh.enable = true;

  nano flake.nix
     {
      description = "basic jacky's flake";

      inputs = { 
        nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
      };

      outputs = inputs @ {
        self,
        nixpkgs,
        ...
      }: {
        nixosConfigurations = {
          nixos-homelab = let
            username = "jacky";
            specialArgs = { inherit username;};
          in
            nixpkgs.lib.nixosSystem {
              inherit specialArgs;
              system = "x86_64-linux";

              modules = [  
                ./configuration.nix  
              ];
            };

        };
      };
    }



  * 目的： 使用nano编辑器编辑配置文件，配置系统。
  
8. 安装系统
  nixos-install
  reboot
  nixos-rebuild switch --flake .#nixos-homelab
  passwd jacky
  ssh jacky@10.0.0.5
  * 目的： 根据配置文件安装系统。
9.更改权限
  sudo chmod -R 700 /boot

