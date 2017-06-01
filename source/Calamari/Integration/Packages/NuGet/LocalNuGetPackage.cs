﻿using System;
using System.IO;
using System.Linq;
using Calamari.Util;
using SharpCompress.Archives.Zip;
using SharpCompress.Readers.Zip;
#if USE_NUGET_V3_LIBS
using NuGet.Packaging;
#else
using NuGet;
#endif

namespace Calamari.Integration.Packages.NuGet
{
    internal class LocalNuGetPackage 
    {
        private readonly string filePath;
        private readonly Lazy<ManifestMetadata> metadata; 

        public LocalNuGetPackage(string filePath)
        {
            Guard.NotNullOrWhiteSpace(filePath, "Must supply a non-empty file-path");

            if (!File.Exists(filePath))
                throw new FileNotFoundException($"Could not find package file '{filePath}'"); 

            this.filePath = filePath;
            metadata = new Lazy<ManifestMetadata>(()=>ReadMetadata(this.filePath));
        }

        public ManifestMetadata Metadata => metadata.Value;

        public void GetStream(Action<Stream> process)
        {
            using (var fileStream = File.OpenRead(filePath))
            {
                process(fileStream);
            }
        }

        static ManifestMetadata ReadMetadata(string filePath)
        {
            using (var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read))
            using (var archive = ZipArchive.Open(fileStream))
            {
                foreach (var entry in archive.Entries)
                {
                    if (entry.IsDirectory || !IsManifest(entry.Key))
                        continue;

                    using (var manifestStream = entry.OpenEntryStream())
                    {
                        var manifest = Manifest.ReadFrom(manifestStream, true);
                        return manifest.Metadata;
                    }
                }

                throw new InvalidOperationException("Package does not contain a manifest");
            }
        }

        static bool IsManifest(string path)
        {
            return Path.GetExtension(path).Equals(CrossPlatform.GetManifestExtension(), StringComparison.OrdinalIgnoreCase);
        }
    }
}