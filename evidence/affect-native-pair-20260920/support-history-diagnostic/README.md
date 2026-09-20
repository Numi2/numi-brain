# Native support-history follow-up

Status: **partial; no completed behavior comparison or benefit result**.

This separate follow-up used read-only, environment-gated instrumentation to retain accepted Matter support history after publication. It made no changes to solver arithmetic, controller behavior, or frozen inputs. The enabled and disabled configs differ only in affect enablement, isolated artifact directory, and run identifier; after those fields are removed, both configs match each other and the earlier diagnostic pair.

The captured values are humanSupportHistories[12].w for accepted roots 98–103. Both runs produced the same sequence:

| Accepted root | Timestamp (µs) | Normal impulse |
| ---: | ---: | ---: |
| 98 | 9,900 | 0.0363973826 |
| 99 | 10,000 | 0.040729858 |
| 100 | 10,100 | 0.0402381532 |
| 101 | 10,200 | 0.0375341512 |
| 102 | 10,300 | 0.0313873626 |
| 103 | 10,400 | 0.0159574524 |

The sequence peaks at root 99; the last recorded value is below the root-98 value. This bounded trace does not establish a safe solver or contact correction, or qualify the contact as physically calibrated.

Both arms then rejected control step 104 after 103 accepted roots. Matter reported NM_STATUS_CONTACT_FAILURE (code 6), support row 12, candidate normal impulse -0.000127762556, support residual 0.00201139692, and rigid residual 0.000509521575. The rejected sample hash matches across arms. The frozen 10,002-root horizon was not reached, so behavior evaluation remains incomplete and no pain/pleasure benefit is demonstrated.

The enabled and disabled sample hashes still differ at control step 30, only in sensorPacketFingerprint. The enabled and disabled fingerprints are 13990843329145935236 and 7627405345143549431; their transaction fingerprint is the same (6264196391978025970), and all seven canonical channel descriptors, value hashes, and validity hashes match. The cause is unknown. GPU allocation identity is plausible but unconfirmed because the compared buffer addresses were not captured. This remains a strict sample-identity mismatch; exact matched provenance is not established.

The paired values and interpretation are recorded in [support-history-report.json](support-history-report.json). Evidence hashes:

- Enabled config 3ac358aa97790a0ce8ffda5ad42c313921f92b9705aa4a1958c4494f6f6b9605; log 8a9224e0326e8103faea8782fee6dd63db87ea421d06c4f06150edfb99cc3adb; failure artifact 177d1bdf3fda7d515ff69410d8c2ca925e5f27d79077d68491110720d6609194.
- Disabled config 180683ca073f4d0262676cc5fcfd45fc178aada59c99c9b62ea357122e45322b; log e4b239dc701b69ac0fca93cdb3e4148b89c1463e99b3bff75a352018d0516e96; failure artifact 8d1f94b0e6691d4a1eab364f53a7c14835e6d1b35f92b801fff99aed52476c8d.
- Build log 6dece1b1c652cb1d89497ef2e80b9c1049b35df909269f32781f46851dcf3fac; [gzip-compressed diagnostic source patch](diagnostic-source.patch.gz) archive SHA-256 bc912308e10c92413dbf564f7aa376d932a946db8095dec2b683c4e263355420 (uncompressed diff SHA-256 cf6c8ab5cc771c42290f1e8134390945976b01ee589d43618a90d9ce2600fb7e); report SHA-256 5d919de5f464f8aab74df4a812f06e43423536368cd3168cbe731cd1debf5487.

The protocol SHA-256 is 3af89a431c40159dcd4cf6b325e41c10467ccf3a22089df07974498729a265ea; publication SHA-256 is fba2ead02f37baf4e6e8311e20af0c4e7de5d2634979dfb7e8204df78adce7f6. The diagnostic source was pinned at 04d5faf0926ec1e498c105b38ea1c16ea5d09f0c. The full native artifact stores remain on the Mac mini; this directory retains the compact pair artifacts, exact configs, logs, and source patch.
