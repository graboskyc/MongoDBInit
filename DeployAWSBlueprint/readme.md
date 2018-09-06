# Deploy AWS Blueprint 
This is a basic tool to deploy a series of AWS Instances when building a Cloud Formation or using Terraform / Habitat or others is overkill.

# Use
## Help
```
$ python deployAWSBlueprint.py --help
usage: deployAWSBlueprint.py [-h] [-b BLUEPRINT] [-s] [-d DAYS]

CLI Tool to esily deploy a blueprint to aws instances

optional arguments:
  -h, --help    show this help message and exit
  -b BLUEPRINT  path to the blueprint
  -s, --sample  download a sample blueprint yaml
  -d DAYS       how many days should we reserve this for before reaping
```

## Sample
```
$ python deployAWSBlueprint.py -b sampleblueprint.yaml
```
## Blueprint Syntax
See the [sampleblueprint.yaml](sampleblueprint.yaml) for an example. But here is the hierarchy:

| Root | Child | Child | Notes |
|----|---|-|-|
| `apiversion: v1` | | | API version to use, use v1 for now | 
|` resources` | | | begins list of things to dpeloy |
| | `-name` | | name of deployed vm |
| | `description` | | used in description tag |
| | `os` | | `ubuntu`,`rhel`,`win2016dc`, `amazon`, or `amazon2` |
| | `size` | | name of AWS sizes |
| | `postinstallorder` | | order of operations, only use if tasks are provided. Useful for things where one VM must be configured before others. Lower numbers get done before higher ones. |
| | `tasks` | | OPTIONAL and completed in order | 
| | | `-type` | `playbook`, `script` for ansible or bash/winrm |
| | | `url` | URL to where the script sits |
| | | `description` | text field to describe what it does |

## Order of operations
* All instances are deployed in the order listed. We use launch instance API and check for pass/fail
* VM names are prepended with a random 8 character string and taged with `use-group` of this UUID so you know they were deployed together
* Wait for all instances to return `running` state
* **NOT IMPLEMENTED YET BELOW THIS LINE:**
* The post configuration plan is generated as follows:
  * Loop through blueprint and find all resources that have a `task` list
  * Order the resources based on `postinstallorder` in ascending order
  * Tasks for each resource are done in order listed
  * Execute this plan in the order provided