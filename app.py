from fastapi import FastAPI, Query, Request
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse, Response
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from pydantic import BaseModel, HttpUrl
import json
import asyncio
import os
import tempfile
import shutil
from typing import Optional, Dict, Any, Union, List
import aiohttp

app = FastAPI(title="yt-dlp URL Extractor API")

class VideoResponse(BaseModel):
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

async def run_yt_dlp_command(url: str) -> Union[Dict[str, Any], str]:
    """Execute yt-dlp command and return the output"""
    try:
        cmd = ["yt-dlp", "--dump-json", url]
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            return stderr.decode('utf-8')
        
        return json.loads(stdout.decode('utf-8'))
    except json.JSONDecodeError:
        return stdout.decode('utf-8')
    except Exception as e:
        return str(e)

async def download_video(video_url: str, output_path: str) -> Union[str, None]:
    """Download video from URL to specified path"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(video_url) as response:
                if response.status != 200:
                    return f"Failed to download: HTTP {response.status}"
                
                with open(output_path, 'wb') as f:
                    while True:
                        chunk = await response.content.read(1024 * 1024)  # 1MB chunks
                        if not chunk:
                            break
                        f.write(chunk)
        return None
    except Exception as e:
        return str(e)

async def get_video_url(url: str) -> Union[Dict[str, Any], str]:
    """Get the video URL from yt-dlp"""
    result = await run_yt_dlp_command(url)
    
    if isinstance(result, dict):
        # Priority for combined audio+video formats with lower resolution
        combined_formats = []
        
        # Look for format with audio and video combined (typically format_id 18 for 360p)
        if "formats" in result:
            for format in result["formats"]:
                # Check if both audio and video are in the same format
                if "acodec" in format and "vcodec" in format:
                    if format.get("acodec") != "none" and format.get("vcodec") != "none":
                        combined_formats.append({
                            "format_id": format.get("format_id"),
                            "url": format.get("url"),
                            "resolution": format.get("resolution", "unknown"),
                            "ext": format.get("ext", "unknown")
                        })
        
        # Sort combined formats by resolution (to get the smallest one first)
        combined_formats.sort(key=lambda x: x.get("resolution", "9999p"))
        
        # Return the smallest combined format, or direct URL if no combined format
        if combined_formats:
            return {
                "success": True, 
                "data": {
                    "smallest_video_with_audio": combined_formats[0]
                }
            }
        elif "url" in result:
            # Fallback to direct URL if available
            return {
                "success": True, 
                "data": {
                    "url": result["url"]
                }
            }
        else:
            # Last resort, return first format with URL
            for format in result.get("formats", []):
                if "url" in format:
                    return {
                        "success": True, 
                        "data": {
                            "url": format["url"],
                            "format_id": format.get("format_id")
                        }
                    }
            
            return {"success": False, "error": "No valid URL found in the response"}
    else:
        return {"success": False, "error": result}

@app.get("/info", response_model=VideoResponse)
async def extract_info(url: str = Query(..., description="Video URL to extract information from")):
    """Extract video URL information using yt-dlp"""
    result = await get_video_url(url)
    return result

@app.get("/file_metadata", response_model=VideoResponse)
async def get_file_metadata(url: str = Query(..., description="Video URL to get metadata")):
    """Download video from specified URL and return JSON with the same format as info"""
    # First get the video URL using yt-dlp
    result = await get_video_url(url)
    
    if not result.get("success", False):
        return result
    
    # Extract the video URL from the result
    video_data = result.get("data", {})
    if "smallest_video_with_audio" in video_data:
        video_url = video_data["smallest_video_with_audio"]["url"]
        ext = video_data["smallest_video_with_audio"].get("ext", "mp4")
    elif "url" in video_data:
        video_url = video_data["url"]
        ext = "mp4"  # Default extension
    else:
        return {"success": False, "error": "No valid URL found in the response"}
    
    # Create temporary directory
    temp_dir = tempfile.mkdtemp(dir="/tmp")
    try:
        # Generate a filename
        video_filename = f"video.{ext}"
        output_path = os.path.join(temp_dir, video_filename)
        
        # Download the video
        error = await download_video(video_url, output_path)
        if error:
            return {"success": False, "error": error}
            
        # Instead of returning the file, return the same JSON as extract
        # This matches the expected behavior described in the requirements
        shutil.rmtree(temp_dir, ignore_errors=True)  # Clean up the temp directory
        return result
    except Exception as e:
        # Clean up in case of error
        shutil.rmtree(temp_dir, ignore_errors=True)
        return JSONResponse(
            content={"success": False, "error": str(e)},
            status_code=500
        )

@app.get("/stream", response_class=StreamingResponse)
async def stream_video(url: str = Query(..., description="Video URL to stream")):
    """Stream video directly to the client"""
    # First get the video URL using yt-dlp
    result = await get_video_url(url)
    
    if not result.get("success", False):
        return JSONResponse(content=result, status_code=400)
    
    # Extract the video URL from the result
    video_data = result.get("data", {})
    if "smallest_video_with_audio" in video_data:
        video_url = video_data["smallest_video_with_audio"]["url"]
    elif "url" in video_data:
        video_url = video_data["url"]
    else:
        return JSONResponse(
            content={"success": False, "error": "No valid URL found in the response"},
            status_code=400
        )
    
    # Create streaming response by proxying the video URL
    async def stream_video_content():
        async with aiohttp.ClientSession() as session:
            async with session.get(video_url) as response:
                if response.status != 200:
                    yield f"Failed to download: HTTP {response.status}".encode()
                    return
                
                while True:
                    chunk = await response.content.read(1024 * 1024)  # 1MB chunks
                    if not chunk:
                        break
                    yield chunk
    
    # Get content type from first request
    async with aiohttp.ClientSession() as session:
        async with session.head(video_url) as response:
            content_type = response.headers.get("Content-Type", "video/mp4")
    
    return StreamingResponse(stream_video_content(), media_type=content_type)

@app.get("/download", response_class=FileResponse)
async def download_video_file(url: str = Query(..., description="Video URL to download")):
    """Download video and serve the file directly to client"""
    # First get the video URL using yt-dlp
    result = await get_video_url(url)
    
    if not result.get("success", False):
        return JSONResponse(content=result, status_code=400)
    
    # Extract the video URL from the result
    video_data = result.get("data", {})
    if "smallest_video_with_audio" in video_data:
        video_url = video_data["smallest_video_with_audio"]["url"]
        ext = video_data["smallest_video_with_audio"].get("ext", "mp4")
    elif "url" in video_data:
        video_url = video_data["url"]
        ext = "mp4"  # Default extension
    else:
        return JSONResponse(
            content={"success": False, "error": "No valid URL found in the response"},
            status_code=400
        )
    
    # Create temporary directory
    temp_dir = tempfile.mkdtemp(dir="/tmp")
    try:
        # Generate a filename
        video_filename = f"video.{ext}"
        output_path = os.path.join(temp_dir, video_filename)
        
        # Download the video
        error = await download_video(video_url, output_path)
        if error:
            return JSONResponse(
                content={"success": False, "error": error},
                status_code=500
            )
        
        # Return the file directly
        return FileResponse(
            path=output_path,
            filename=video_filename,
            media_type=f"video/{ext}"
        )
    except Exception as e:
        # Clean up in case of error
        shutil.rmtree(temp_dir, ignore_errors=True)
        return JSONResponse(
            content={"success": False, "error": str(e)},
            status_code=500
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
