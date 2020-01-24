# Video Image Burner (VIB)

This repository can be used to burn in images into a video with the help
of FFmpeg. A Docker file is provided that builds a Docker image
containing FFmpeg and BaseX which provides a RestXQ service. Also a
simple web interface is available that allows to add a job and to track
its status.


## Building the Docker image

Just execute the following command to build the Docker image:

    docker build -t video_image_burner .


## Run the Docker image

To run the image, the web interface port (8984) has to be mapped to a
local port (here: 9010).

Furthermore shared folders are used to exchange the input/output files.
These folders have to be bound to local folders:
- `/root/input` for input (here: `/vib-files` or `c:\vib-files`)
- `/root/output` for output (here: `/vib-out` or `c:\vib-out`)

This can be achieved with the following command (Linux host):

    docker run \
    --mount type=bind,source=/vib-files,target=/root/input \
    --mount type=bind,source=/vib-out,target=/root/output \
    -p 9010:8984 video_image_burner

The value for the `source` parameter needs to be set to a local folder
on the system where Docker is executed. On a Windows host this may look
like:

    docker run ^
    --mount type=bind,source=c:\vib-files,target=/root/input ^
    --mount type=bind,source=c:\vib-out,target=/root/output ^
    -p 9010:8984 video_image_burner

If the Docker image is executed on a Linux host which provides hardware
acceleration using VAAPI, it can be employed for encoding. For this the
following additional parameter has to be added to the `docker run` call:

    --device /dev/dri

If hardware acceleration is available, a checkbox to use it is provided
in the web interface.


## Run standalone

The burner can also be used without Docker. This requires [BaseX](http://basex.org) to be
installed (tested with version 9.3), including [Saxon](http://saxon.sourceforge.net) (HE) 9 (tested with
version 9.9.1.6). Hereby Saxon's `saxon9he.jar` has to be copied to the
`lib/custom` subfolder of the BaseX installation. Furthermore the FFmpeg
commands `ffmpeg` and `ffprobe` must be available.

The following BaseX command has then to be executed in the repository
root folder to start the burner (which will be available on port 8984):

	basexhttp


## Web interface

The web interface is available at:

    localhost:9010


### Usage

As mentioned above shared folders are used to exchange input/output
files between a user and the Video Image Burner (due to the file sizes).
Therefore the shared folders have somehow to be made accessible for
users e.g. via FTP or as a Windows share.

First a source file (currently: MP4 with H.264 video) has to be put into
the input folder. It then can be selected in the pull-down menu as
source.

Furthermore the corresponding images have to be provided. Currently
this happens in form of a ZIP archive. Every file in this archive
represents a screen update (e.g. new content shown or any visible
content is hidden). Each file has to be a PNG file with a transparent
background and its resolution must be the same as the resolution of the
source video. A filename also represents the point in time (in seconds)
from which on a file shall be shown (until the next file "gets active")
e.g. `12.png` or `420.84.png`.

Finally a few options can be configured e.g. whether the video shall be
scaled to a certain resolution or not. If the Docker host provides
hardware acceleration, it can also be enabled/disabled for the process.

When the process is started, a status page is shown. It displays the
progress of the current burn-in process and further details including
the FFmpeg output. It also indicates the successful completion of the
process - or any errors that occur.

After the process has finished, the output folder contains the resulting
output file. If not yet present, the file extension `.mp4` is appended.


## REST interface

Adding a job and querying the current status can also be done using the
REST interface. Similar to the web interface, input/output files have to
be exchanged using a shared folder, too.

A list of input files available in the input folder can be retrieved
using the `essences` GET request.

The burn-in process is started using the `jobs` POST request. The
current job status is retrieved using the `jobs/<job-id>` GET request.

Note that Cross-Origin Resource Sharing (CORS) is enabled i.e. requests
from any origin are processed. This behaviour can be disabled by
removing the paragraph related to CORS in `/webapp/WEB-INF/web.xml`.

If a request succeeds, it returns the HTTP status code `200 OK`.
Otherwise code `400 Bad Request` is returned, together with a JSON
structure consisting of a string `error` that further describes the
reason for failing, for example:

```json
{
  "error":"The requested job does not exist."
}
```

### `essences` GET request

This request is a helper request that provides an (ordered) list of all
available input files (suitable/designated for embedding) in the input
folder. Currently this includes all files that have an `.mp4` extension.

No parameters are available for this request.

Upon success the response is in JSON format and simply an array of
strings, for example:

```json
[
  "foo.mp4",
  "bar.mp4"
]
```

Each string is the filename of an essence available in the defined input
folder.

### `jobs` POST request

This request is used to add a new burn-in job. The new job is
immediately started despite any other already running jobs. Thus it has
to be taken care that only a single job is active in parallel (or at
least not too many jobs).

The following request parameters are available:
- `essence` (mandatory): The filename of the input file which is stored
  in the input folder and into which the images shall be burnt in.
- `images` (mandatory): A ZIP file which contains all the images to be
  burnt in. For this reason each image filename has to correspond to the
  media time at which it actually "gets active".
- `resolution` (optional): The desired target resolution of the output
  video. An empty string (default) to indicate that the video shall not
  be resized, otherwise a value of the format `1280x720` (= width by
  height in pixels).
- `quality` (mandatory): The target quality of the output video. In
  general the Constant Rate Factor (CRF) is used (range 0 to 63), which
  is an abstract value that reflects the desired quality/size tradeoff
  to get a constant output quality (the lower the value, the better the
  quality). In case of hardware acceleration, a similar means called
  "global quality" (range 1 to 51) is used internally.
  Note that in tests a video processed with the value 0 (only allowed
  without hardware acceleration) was not played by all tested players.
  Therefore it is recommended to use a different value.
- `hwaccel` (optional): Set to `1` if the encoding shall be done using
  hardware acceleration (requires hardware acceleration to be
  available), otherwise set to `0` (default).

Note that the HTTP content type `multipart/form-data` has to be used for
this request, as a file is uploaded here.

Upon success the response is in JSON format and contains the ID of the
newly created job as part of the following JSON object:

```json
{
  "job_id": <job_id>
}
```

### `jobs/<job-id>` GET request

This request allows to query the current status of a previously added
job. The information is still available after a job has ended.

The following request parameters are available:
- `job_id` (mandatory): The job ID of the queried job.
- `verbose` (optional): Set to `1` if additional fields (`log` and
  `cmdline`) shall be contained in the response, otherwise set to `0`
  (default).

Upon success the response is in JSON format and contains different
fields as part of the following JSON object:

```json
{
  "job_id": <job_id>
  "essence": <essence>
  "exitStatus": <exitStatus>
  "progressPercentage": <progressPercentage>
  "progressText": <progressText>
  "log": <log>
  "cmdline": <cmdline>
}
```

The following field values are transmitted:
- `job_id`: The job ID of the queried job.
- `essence`: The filename of the input file which is stored in the
  input folder and into which the images shall be burnt in.
- `exitStatus`: The exit code of the FFmpeg process or `-1`, if FFmpeg
  is still running. If the process finished without any error, the exit
  code will be `0`. Otherwise it will be a value larger than zero and
  further details can be retrieved from FFmpeg's output messages.
- `progressPercentage`: Percentage of the processed video timeline.
- `progressText`: Status message describing the conversion progress,
  intended for user display.
- `log`: The FFmpeg output messages (from `stderr`) so far.
- `cmdline`: The command line that was used to invoke FFmpeg.

Note: The fields `log` and `cmdline` are only available in verbose mode
(see above).

### Examples

The following example requests are done using [cURL](https://curl.haxx.se/). A burner running
locally is assumed. Note that Windows uses a different character for
line continuation (`^` instead of `\`).

Retrieve a list of all available essences:

	curl http://localhost:9010/essences

Burn images (stored in `image.zip`) into the essence `example.mp4`,
using a target quality of `23` and hardware acceleration:

    curl -F essence=example.mp4 -F images=@images.zip \
    -F quality=23 -F hwaccel=1 http://localhost:9010/jobs

Retrieve the current status of a certain job (with verbose output):

    curl -d verbose=1 http://localhost:9010/jobs/21646c0b-dba7-4d2a-9cdb-24c64f8291ca


## Operation

The web and REST interfaces are provided using [BaseX](http://basex.org/) together with
RestXQ. The [Saxon (HE) processor](http://saxon.sf.net) is used as well, as it is able to
process XSLT versions newer than 1.0. The actual burn-in process is done
using [FFmpeg](https://ffmpeg.org/). In contrast to the other prerequisites, it is not
downloaded but compiled when the Docker image is built, in order to
include the necessary codecs/filters e.g. for hardware acceleration.

The uploaded images are combined to a virtual video file using FFmpeg's
`concat` container (a custom format by FFmpeg). This file is then
rendered on top of the actual source file video picture. If selected,
the video image is finally scaled to the specified resolution (if
desired) prior to encoding it to H.264 again (using a certain
quality/CRF).


### Details

The following files are relevant for the actual application:
- `.basexhome`: empty BaseX helper file to indicate home directory.
- `create_concat_file_from_dir.xsl`: XSLT used to create a helper file
  in `concat` format, refering to all images in a certain directory.
- `webapp/video_image_burner.xqm`: application source code as XQuery module.
- `webapp/WEB-INF/jetty.xml`: Jetty web server config
- `webapp/WEB-INF/web.xml`: web application config

The process itself starts by creating a temporary directory in order to
store different temporary files during conversion. This also includes
the images unpacked from the ZIP file. In addition the `concat`
container (as described above) is automatically created using an XSLT
transformation.

A helper script is assembled in order to call FFmpeg with the required
parameters. This script also allows to redirect the `stderr` output to a
log file which is queried later for status updates. An additional file
contains progress data that is regularly updated by FFmpeg. A further
file contains (static) internal job information required later.

Before the actual conversion is started, FFprobe is executed to
determine the input file duration. This information is used later during
the conversion itself for proper progress information.

When the current status is retrieved using the respective REST API call,
constant information (e.g. the essence name or the command line to call
FFmpeg) is combined with information that is read from regularly updated
files e.g. the log messages so far and the current progress. For this
reason the progress is not shown in the log to prevent to "pollute" it,
hiding other, more important messages and to not require too much
scrolling.

The actual combination of the images with the original video is done
using FFmpeg filters. As filters are involved which have more than one
input or output, FFmpeg's complex filtergraph has to be used. In general
the `overlay` filter is used to render the images onto the video image.
If desired, the output is then scaled to a different resolution. In case
of hardware acceleration, the image is uploaded to the graphic card
before. In such a case the scaling is done in hardware, too.

So for each job, the following temporary files are created and used
internally (e.g. further static information required later) and stored
in the system's temp folder:
- `vib-log-<job-id>.log`:
  FFmpeg's output to `stderr`; expands while FFmpeg is running.
- `vib-log-<job-id>.log.duration`:
  FFprobe's output containing the essence duration.
- `vib-log-<job-id>.log.progress`:
  FFmpeg progress/status; regularly updated by FFmpeg while running.
- `vib-log-<job-id>.log.finished`:
  FFmpeg exit code; created after FFmpeg exits.
- `vib-log-<job-id>.log.info.xml`:
  burner internal job data e.g. the used FFmpeg command line.

In the system's temp folder for each job also an additional folder is
created which contains the following files:
- `concat.txt`:
  The `concat` container, referring to the images.
- `vib_burn`:
  The shell script that does the actual work e.g. to invoke FFmpeg.
- `*.png`:
  The image files, extracted from the uploaded ZIP file.

This job folder is deleted after the job finishes.