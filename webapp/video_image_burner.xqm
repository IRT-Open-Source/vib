(: Video Image Burner (VIB)
 :
 : MIT License
 :
 : Copyright 2019 Institut für Rundfunktechnik GmbH, Munich, Germany
 :
 : Permission is hereby granted, free of charge, to any person obtaining a copy
 : of this software and associated documentation files (the "Software"), to deal
 : in the Software without restriction, including without limitation the rights
 : to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 : copies of the Software, and to permit persons to whom the Software is
 : furnished to do so, subject to the following conditions:
 :
 : The above copyright notice and this permission notice shall be included in all
 : copies or substantial portions of the Software.
 :
 : THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 : IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 : FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 : AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 : LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 : OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 : SOFTWARE.
 :)

module namespace vib = 'http://www.irt.de/irt_restxq/video_image_burner';

declare variable $vib:essence_path as xs:string := 'input/';
declare variable $vib:output_path as xs:string := 'output/';


(: returns an (ordered) list of the existing essences in the input folder :)
declare function vib:essence_files() {
    if (file:exists($vib:essence_path))
    then
      for $file in file:list($vib:essence_path)[ends-with(lower-case(.), '.mp4')]
      order by $file
      return $file
    else ()
};

(: returns the aforementioned list :)
declare 
  %rest:path("/essences")
  %output:method("json")
  %output:json("format=basic")
  function vib:essences() {
    <j:array xmlns:j="http://www.w3.org/2005/xpath-functions">
      {vib:essence_files() ! <j:string>{.}</j:string>}
    </j:array>
  };

(: returns whether hardware acceleration is available :)
declare function vib:hw_accel_available() {
    file:exists('/dev/dri') (: check for DRI device :)
};

(: web interface homepage :)
declare 
  %rest:path("/")
  %output:method("xhtml")
  function vib:overview() {
    <html>
      <head>
        <title>Video Image Burner</title>
        <script>
            function add_job(form) {{
            	fetch('jobs', {{
            		method: "post",
            		body: new FormData(form)
    			}}).then(function(response) {{
    				response_tmp = response;
    				return (response.status == 200 || response.status == 400) ? response.json() : null;
    			}}).then(function(json) {{
    				switch (response_tmp.status) {{
    				    case 200:
    					   window.location.href = "jobs/" + json.job_id + "/status-page";
    					   break;
    				    case 400:
    				       document.getElementById("status").innerHTML = json.error;
    					   break;
    				}}
    			}});
            }}
        </script>
      </head>
      <body>
        <h1>Video Image Burner - Start</h1>
        <form onsubmit="add_job(this); return false;">
            <label>Available .mp4 source videos:<br/>
                <select name="essence" required="required">
                    <option selected="selected"/>
                    {vib:essence_files() ! <option>{.}</option>}
                </select>
            </label><br/>
            <label>Images ZIP archive:<br/>
                <input type="file" name="images" required="required"/>
            </label><br/>
            <label>Output resolution:<br/>
                <select name="resolution">
                    <option selected="selected" value="">(unchanged)</option>
                    <option>3840x2160</option>
                    <option>1920x1080</option>
                    <option>1280x720</option>
                    <option>960x540</option>
                    <option>640x360</option>
                    <option>512x288</option>
                    <option>480x270</option>
                    <option>320x180</option>
                </select>
            </label><br/>
            <label>Output quality (lower number = higher bitrate):<br/>
                <select name="quality">
                    <option>26</option>
                    <option selected="selected">23</option>
                    <option>20</option>
                    <option>15</option>
                </select>
            </label><br/>
            {if (vib:hw_accel_available()) then (
            <label>Use hardware acceleration:<br/>
                <input type="checkbox" name="hwaccel" value="1" checked="checked"/>
            </label>,<br/>
            ) else ()}
            <button type="submit">Burn in</button><br/>
            <b><font color="Red"><span id="status"/></font></b>
        </form>
      </body>
    </html>
  };

(: web interface status page :)
declare 
  %rest:path("/jobs/{$job_id}/status-page")
  %output:method("xhtml")
  function vib:job_status_web(
    $job_id as xs:string
  ) {
    <html>
      <head>
        <title>Video Image Burner</title>
      </head>
      <body>
        <h1><a href="/">Video Image Burner</a> - Job status</h1>
        Essence: <b><span id="essence">(please wait)</span></b><br/>
        Status: <b><span id="exit_status">(please wait)</span></b><br/>
        Progress: <progress id="progress" max="100" style="width: 30%"/> <b><span id="progress_text">(please wait)</span></b><br/>
        Log:
        <textarea id="log_content" readonly="readonly" style="width: 100%; height: 70%">(please wait)</textarea>
        <script type="text/javascript">
            function update() {{
    			fetch('.?verbose=1').then(function(response) {{
    				response_tmp = response;
    				return response.status == 200 ? response.json() : null;
    			}}).then(function(json) {{
    				switch(response_tmp.status) {{
    				    case 200:
    				        document.getElementById("essence").innerHTML = json.essence;
    				        
    				        let exit_status = json.exitStatus
    					    switch(exit_status) {{
    					    case -1:
    					       document.getElementById("exit_status").innerHTML = '<font color="Blue">⏳ Running...</font>';
    					       break;
    					    case 0:
    					       document.getElementById("exit_status").innerHTML = '<font color="Green">✓ Finished successfully.</font>';
    					       document.getElementById("log_content").style.backgroundImage = 'linear-gradient(to bottom right, LightGreen, Green)';
    					       clearInterval(call_update);
    					       break;
    					    default:
    					       document.getElementById("exit_status").innerHTML = '<font color="Red">✕ Finished with error(s).</font>';
    					       document.getElementById("log_content").style.backgroundImage = 'linear-gradient(to bottom right, LightSalmon, Red)';
    					       clearInterval(call_update);
    					       break;
    					    }}
    						document.getElementById("log_content").innerHTML = json.log;
    						if (json.progressPercentage != 0 ) {{
    						  document.getElementById("progress").value = json.progressPercentage;
    						}}
    						document.getElementById("progress_text").innerHTML = json.progressText;
    
                            // scroll to bottom
                            let textarea = document.getElementById('log_content');
                            textarea.scrollTop = textarea.scrollHeight;
                            break;
    					default:
    						document.getElementById("log_content").innerHTML = "(not available)";
    						break;
    				}}
    			}});
			}}
			
			var call_update = setInterval(update, 1000);
			update();
        </script>
      </body>
    </html>
  };

(: returns an error message :)
declare function vib:return_error($message as xs:string) {
    <rest:response>
        <http:response status="400"/>
    </rest:response>,
    <j:map xmlns:j="http://www.w3.org/2005/xpath-functions">
      <j:string key="error">{$message}</j:string>
    </j:map>
};

(: returns the status of a specific job :)
declare 
  %rest:path("/jobs/{$job_id}")
  %rest:query-param("verbose", "{$verbose}", 0)
  %output:method("json")
  %output:json("format=basic")
  function vib:job_status(
    $job_id as xs:string,
    $verbose as xs:integer
  ) {
    let $job_id_sanitized := replace($job_id, '[^0-9a-f-]', '')
    let $log_filename := concat(file:temp-dir(), file:dir-separator(), 'vib-log-', $job_id_sanitized, '.log')
    let $duration_filename := concat($log_filename, '.duration')
    let $progress_filename := concat($log_filename, '.progress')
    let $finished_filename := concat($log_filename, '.finished')
    let $info_filename := concat($log_filename, '.info.xml')
    
    (: check if job exists :)
    return
      if (not(file:exists($info_filename)))
      then vib:return_error('The requested job does not exist.')
      else
        (: retrieve infos :)
        let $info_doc := doc($info_filename)
        let $exit_status := if (file:exists($finished_filename)) then xs:integer(file:read-text($finished_filename)) else -1
        let $duration_s := xs:decimal(doc($duration_filename)/ffprobe/format/@duration)
        let $progress_content := if (file:exists($progress_filename)) then file:read-text-lines($progress_filename) else ()
        let $progress_map := map:merge(for $x in $progress_content return map:entry(substring-before($x, '='), substring-after($x, '=')), map { 'duplicates': 'use-last' }) (: use only the most recent key/value set :)
        let $progress_out_time_ms := xs:decimal(($progress_map('out_time_ms'), '0')[1])
        let $progress_size_raw := file:size($info_doc/info/outputfile/text())
        let $progress_size := format-number($progress_size_raw div 1000 div 1000, '0.0')
        let $progress_text := if (exists($progress_content)) then concat($progress_map('out_time'), ' (speed: ', $progress_map('speed'), ', output size: ', $progress_size, ' MB)') else '...'
        let $progress_percentage := if ($progress_map('progress') eq 'end') then 100 else ($progress_out_time_ms div 1000000.0 div $duration_s * 100)
        
        return
        <j:map xmlns:j="http://www.w3.org/2005/xpath-functions">
          <j:string key="job_id">{$job_id_sanitized}</j:string>
          <j:string key="essence">{$info_doc/info/essence/text()}</j:string>
          <j:number key="exitStatus">{$exit_status}</j:number>
          <j:number key="progressPercentage">{$progress_percentage}</j:number>
          <j:string key="progressText">{$progress_text}</j:string>
          {
            (: verbose mode :)
            if ($verbose eq 1)
            then
                let $log_content := string-join(file:read-text-lines($log_filename), '&#xa;')
                return (
                    <j:string key="log">{$log_content}</j:string>,
                    <j:string key="cmdline">{$info_doc/info/cmdline/text()}</j:string>
                )
            else ()
          }
        </j:map>
  };

(: adds a new job :)
declare 
  %rest:path("/jobs")
  %rest:POST
  %rest:form-param("essence", "{$essence}")
  %rest:form-param("images", "{$images}")
  %rest:form-param("resolution", "{$resolution}", '')
  %rest:form-param("quality", "{$quality}")
  %rest:form-param("hwaccel", "{$hwaccel}", 0)
  %output:method("json")
  %output:json("format=basic")
  function vib:job_add(
    $essence as xs:string,
    $images as map(*),
    $resolution as xs:string,
    $quality as xs:integer,
    $hwaccel as xs:integer
  ) {
    let $images_archive := $images(map:keys($images)[1])
    let $job_id := random:uuid()
    let $tmp_dir := concat(file:temp-dir(), file:dir-separator(), 'vib-tmp-', $job_id, file:dir-separator())
    
    (: generate main filenames :)
    let $essence_cleaned := replace($essence, file:dir-separator(), '') (: don't allow dir changes :)
    let $essence_filename := concat($vib:essence_path, $essence_cleaned)
    let $essence_filename_escaped := replace($essence_filename, '"', '\\"')
    let $concat_filename := concat($tmp_dir, 'concat.txt')
    let $script_filename := concat($tmp_dir, 'vib_burn')
    let $output_filename := concat($vib:output_path, $essence_cleaned, if (ends-with(lower-case($essence_cleaned), '.mp4')) then () else '.mp4') (: ensure ".mp4" file extension :)
    let $output_filename_escaped := replace($output_filename, '"', '\\"')
    
    (: generate auxiliary filenames :)
    let $log_filename := concat(file:temp-dir(), file:dir-separator(), 'vib-log-', $job_id, '.log')
    let $duration_filename := concat($log_filename, '.duration')
    let $progress_filename := concat($log_filename, '.progress')
    let $finished_filename := concat($log_filename, '.finished')
    let $info_filename := concat($log_filename, '.info.xml')
    
    (: check the specified params :)
    return
      if (not(file:exists($essence_filename)))
      then vib:return_error('The specified essence file does not exist.')
      else
        if (bin:length($images_archive) eq 0)
        then vib:return_error('An image archive must be provided.')
        else
          if (empty(try { archive:options($images_archive) } catch archive:format { () }))
          then vib:return_error('The format of the provided image archive is invalid or unsupported.')
          else
            if (not($resolution eq '' or matches($resolution, '^\d+x\d+$')))
            then vib:return_error('The specified resolution is invalid.')
            else
              if ($hwaccel eq 1 and not(vib:hw_accel_available()))
              then vib:return_error('Hardware acceleration was requested, but is not available.')
              else
                if ($quality lt (if ($hwaccel eq 1) then 1 else 0) or $quality gt (if ($hwaccel eq 1) then 51 else 63))
                then vib:return_error('The specified value for quality is invalid.')
                else
                  if (not($hwaccel = (0, 1)))
                  then vib:return_error('The specified value for hardware acceleration is invalid.')
                  else
                    let $tmp_dir_create := file:create-dir($tmp_dir)
                    
                    (: extract all images to a temporary folder :)
                    let $write_images := archive:extract-to($tmp_dir, $images_archive)
                    
                    (: create concat file, refering to all images :)
                    let $concat_xslt := file:read-text('create_concat_file_from_dir.xsl')
                    let $concat_content := xslt:transform-text(<tmp/>, $concat_xslt, map {'files': string-join(archive:entries($images_archive)/text(), ';')})
                    let $write_concat := file:write-text($concat_filename, $concat_content)
                    
                    (: determine command line params :)
                    let $hwaccel_params := if ($hwaccel eq 1) then ('-vaapi_device', '/dev/dri/render*') else ()
                    let $vcodec := if ($hwaccel eq 1) then 'h264_vaapi' else 'libx264'
                    let $filter_hwaccel := if ($hwaccel eq 1) then ('format=nv12', 'hwupload') else ()
                    let $filter_scale := if ($resolution ne '') then concat(if ($hwaccel eq 1) then 'scale_vaapi' else 'scale', '=', replace($resolution, 'x', ':')) else ()
                    let $filter_complex := string-join(('overlay=eof_action=pass', $filter_hwaccel, $filter_scale), ',') (: if generated concat file longer than video, dont' repeat video frames :)
                    let $quality_params := if ($hwaccel eq 1) then ('-global_quality', $quality) else ('-crf', $quality)
                    
                    (: compose/start conversion script :)
                    let $duration_cmd := string-join(('ffprobe', '-of', 'xml', '-show_entries', 'format=duration', concat('"', $essence_filename_escaped, '"'), '>', concat('"', $duration_filename, '"')), ' ')
                    let $script_cmd := string-join(('ffmpeg', '-nostats', '-progress', concat('"', $progress_filename, '"'), '-y', $hwaccel_params, '-i', concat('"', $essence_filename_escaped, '"'), '-i', concat('"', $concat_filename, '"'), '-filter_complex', $filter_complex, $quality_params, '-vcodec', $vcodec, '-acodec', 'copy', concat('"', $output_filename_escaped, '"'), '2>', concat('"', $log_filename, '"')), ' ')
                    let $finished_cmd := concat('echo $? > "', $finished_filename, '"')
                    let $delete_cmd := concat('rm -r -f "', $tmp_dir, '"')
                    let $write_script := file:write-text-lines($script_filename, ('#!/bin/bash', $duration_cmd, $script_cmd, $finished_cmd, $delete_cmd))
                    let $exec_chmod_script := proc:system('chmod', ('+x', $script_filename))
                    let $exec_script := proc:fork($script_filename)
                    
                    (: write info file :)
                    let $info_content := <info><essence>{$essence_cleaned}</essence><outputfile>{$output_filename}</outputfile><cmdline>{$script_cmd}</cmdline></info>
                    let $write_info := file:write($info_filename, $info_content)
                    
                    return
                    <j:map xmlns:j="http://www.w3.org/2005/xpath-functions">
                        <j:string key="job_id">{$job_id}</j:string>
                    </j:map>
  };