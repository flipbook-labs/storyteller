local function new(className: string, props: { [string]: any }?, children: { [string]: Instance }?)
	local instance = Instance.new(className)

	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end

	if children then
		for name, child in children do
			child.Name = name
			child.Parent = instance
		end
	end

	return instance
end

return new
