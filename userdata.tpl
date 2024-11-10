version: 1.0
tasks:
- task: executeScript
  inputs:
  - frequency: always
    type: powershell
    runAs: localSystem
    content: |-

      # install python 3.10.6 as recommended by Automatic1111
      #$down_path = [Environment]::GetFolderPath("Downloads")
      #$py_url = "https://www.python.org/ftp/python/3.10.6/python-3.10.6-amd64.exe"
      #Invoke-WebRequest $py_url -OutFile "$down_path\python-3.10.6-amd64.exe"

      # Required Modules, Etc.
      #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      #Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      #Set-PSRepository -Name 'PSGallery' -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted
      #Install-Module -Name 7Zip4PowerShell -Force

      # Install 7zip
      # TODO: Install latest 7zip instead of fixed version
      # https://www.7-zip.org/a/7z2401-x64.msi
      #$Installer7Zip = $env:TEMP + "\7z2401-x64.msi"
      $Installer7Zip = "C:\Users\Administrator\Downloads\7z2401-x64.msi"

      $Job = Start-Job -ArgumentList $Installer7Zip -ScriptBlock {
          param($Installer7Zip)
          Invoke-WebRequest "https://www.7-zip.org/a/7z2401-x64.msi" -OutFile $Installer7Zip
          }
      $Job | Wait-Job

      #msiexec /i $Installer7Zip /qn /norestart
      $ZipInstallArgs = @('/i',$Installer7Zip,'/qn','/norestart')
      Start-Process msiexec -WorkingDirectory "C:\Users\Administrator\Downloads\" -NoNewWindow -ArgumentList $ZipInstallArgs -wait
      #Start-Sleep -Seconds 10.0
      #Remove-Item $Installer7Zip

      # install Git
      # TODO: install this explicitly instead of depending on the pre-packaged version

      # Alternative install from .zip package
      #$path = [Environment]::GetFolderPath("MyDocuments")
      $path = "C:\Users\Administrator\Documents"
      $url = "https://github.com/AUTOMATIC1111/stable-diffusion-webui/releases/download/v1.0.0-pre/sd.webui.zip"
      New-Item -Path "$path" -Name "StableDiffusion" -ItemType Directory
      Invoke-WebRequest $url -OutFile "$path\StableDiffusion.zip"
      Expand-Archive -Path "$path\StableDiffusion.zip" -DestinationPath "$path\StableDiffusion" -Force

      # Run update.bat:
      # alternative way to run, but this will pause waiting for keyboard input
      #Start-Process -FilePath "$path\StableDiffusion\update.bat" -WorkingDirectory "$path\StableDiffusion"
      Set-Location -Path "$path\StableDiffusion"
      echo " " | .\update.bat

      # create shortcut to run.bat and name it "StableDiffusion"
      #$DesktopPath = [Environment]::GetFolderPath("Desktop")
      $DesktopPath = "C:\Users\Administrator\Desktop"
      $WshShell = New-Object -comObject WScript.Shell
      $Shortcut = $WshShell.CreateShortcut("$DesktopPath\StableDiffusion.lnk")
      $Shortcut.TargetPath = "$path\StableDiffusion\run.bat"
      $Shortcut.WorkingDirectory = "$path\StableDiffusion"
      $Shortcut.Save()

      # download Models and Loras
      #$model_path = "$path\stable-diffusion-webui\models\Stable-diffusion"
      #$FilesToDownload = @(
      #'http://...model.safetensors',
      #'http://...model.safetensors'
      #)

      # install NVIDIA drivers
      $Bucket = "nvidia-gaming"
      $KeyPrefix = "windows/latest"
      $LocalPath = "C:\Users\Administrator\Desktop\NVIDIA"
      $Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
      foreach ($Object in $Objects) {
          $LocalFileName = $Object.Key
          if ($LocalFileName -ne '' -and $Object.Size -ne 0) {
              $LocalFilePath = Join-Path $LocalPath $LocalFileName
              Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFilePath -Region us-east-1
          }
      }

      Set-Location -Path "$DesktopPath\NVIDIA\windows\latest"
      $ArchivePath = "$DesktopPath\NVIDIA\windows\latest"
      $ArchiveFilename = (Get-Item $LocalFilePath ).Name
      $ArchiveFoldername = (Get-Item $LocalFilePath ).Basename

      $7zArguments = @('x','-bso0','-bsp1','-bse1','-aoa',$LocalFilePath)
      Start-Process -FilePath "C:\Program Files\7-Zip\7z.exe" -NoNewWindow -ArgumentList $7zArguments -wait

      # run setup.exe
      $install_args = @('-passive','-noreboot','-noeula','-nofinish','-s')
      Start-Process -FilePath "$ArchivePath\setup.exe" -NoNewWindow -ArgumentList $install_args -wait # use vars for file/path names

      # set registry values and download the nvidia cert
      New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global" -Name "vGamingMarketplace" -PropertyType "DWord" -Value "2"
      Invoke-WebRequest -Uri "https://nvidia-gaming.s3.amazonaws.com/GridSwCert-Archive/GridSwCertWindows_2023_9_22.cert" -OutFile "$Env:PUBLIC\Documents\GridSwCert.txt"
