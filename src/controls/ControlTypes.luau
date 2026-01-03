local Sift = require("@pkg/Sift")
local gt = require("@pkg/GreenTea")

local ControlType = require("@root/controls/enums/ControlType")

type ControlType = ControlType.ControlType

local export = {}

-- Make sure to update this when adding new control types!
export type StoryControlValueBase = boolean | number | string | Color3 | DateTime | EnumItem
local StoryControlValueBase: StoryControlValueBase = gt.union(
	-- Primitives
	gt.boolean() :: boolean | number | string | Color3 | DateTime | EnumItem,
	gt.number(),
	gt.string(),

	-- Roblox datatypes
	gt.Color3(),
	gt.isTypeof("DateTime") :: DateTime,
	gt.isTypeof("EnumItem") :: EnumItem
)
export.StoryControlValueBase = gt.build(StoryControlValueBase)

local StoryControlValue = gt.union(StoryControlValueBase, gt.array(StoryControlValueBase))
export.StoryControlValue = gt.build(StoryControlValue)
export type StoryControlValue = typeof(StoryControlValue)

local MappedControlOptions = gt.dictionary(gt.string(), StoryControlValueBase)
export.MappedControlOptions = gt.build(MappedControlOptions)
export type MappedControlOptions = typeof(MappedControlOptions)

local SimpleControlOptions = gt.array(gt.string())
export.SimpleControlOptions = gt.build(SimpleControlOptions)
export type SimpleControlOptions = typeof(SimpleControlOptions)

local ControlOptions = gt.union(SimpleControlOptions, MappedControlOptions)
export.ControlOptions = gt.build(ControlOptions)
export type ControlOptions = typeof(ControlOptions)

local function BaseControl<T>(controlType: ControlType, valueType: T)
	return gt.struct({
		type = gt.literal(controlType) :: ControlType,
		default = gt.optional(valueType),
	})
end

local function BaseNumberControl(controlType: ControlType)
	local control = gt.struct({
		type = gt.literal(controlType) :: ControlType,
		default = gt.optional(gt.number()),
		step = gt.optional(gt.number()),
		range = gt.optional(gt.isTypeof("NumberRange", NumberRange.new(0, 1))),
	})

	return gt.withCustom(
		control,
		-- Is it safe to assume that `input` should be typed as the fisrt arg?
		function(input: typeof(control))
			if input.default and input.range then
				if input.default < input.range.Min or input.default > input.range.Max then
					return false,
						`default value "{input.default}" must be a number within the range [{input.range.Min}, {input.range.Max}]`
				end
			end
			return true, nil
		end
	)
end

local function getPossibleOptions(controlOptions: ControlOptions): { string }
	if export.SimpleControlOptions:matches(controlOptions) then
		return controlOptions :: SimpleControlOptions
	elseif export.MappedControlOptions:matches(controlOptions) then
		return Sift.Dictionary.keys(controlOptions)
	end

	return {}
end

local function SelectOneControl(controlType: ControlType)
	local control = gt.struct({
		type = gt.literal(controlType) :: ControlType,
		options = ControlOptions,
		default = gt.optional(gt.string()),
	})

	return gt.withCustom(control, function(input: typeof(control))
		local options = getPossibleOptions(input.options)

		if input.default and not table.find(options, input.default) then
			return false, `value "{input.default}" not found in 'options'`
		end

		return true, nil
	end)
end

local function SelectManyControl(controlType: ControlType)
	local control = gt.struct({
		type = gt.literal(controlType) :: ControlType,
		options = ControlOptions,
		default = gt.optional(gt.array(gt.string())),
	})

	return gt.withCustom(control, function(input: typeof(control))
		if input.default then
			local options = getPossibleOptions(input.options)

			for _, defaultOption in input.default do
				if not table.find(options, defaultOption) then
					return false, `value "{defaultOption}" not found in 'options'`
				end
			end
		end

		return true, nil
	end)
end

local BooleanControl = BaseControl(ControlType.Boolean, gt.boolean())
export.BooleanControl = gt.build(BooleanControl)
export type BooleanControl = typeof(BooleanControl)

local StringControl = BaseControl(ControlType.String, gt.string())
export.StringControl = gt.build(StringControl)
export type StringControl = typeof(StringControl)

local NumberControl = BaseNumberControl(ControlType.Number)
export.NumberControl = gt.build(NumberControl)
export type NumberControl = typeof(NumberControl)

local SliderControl = BaseNumberControl(ControlType.Slider)
export.SliderControl = gt.build(SliderControl)
export type SliderControl = typeof(SliderControl)

local ColorControl = BaseControl(ControlType.Color, gt.Color3())
export.ColorControl = gt.build(ColorControl)
export type ColorControl = typeof(ColorControl)
export type ColourControl = ColorControl

local DateControl = BaseControl(ControlType.Date, gt.isTypeof("DateTime"))
export.DateControl = gt.build(DateControl)
export type DateControl = typeof(DateControl)

local SelectControl = SelectOneControl(ControlType.Select)
export.SelectControl = gt.build(SelectControl)
export type SelectControl = typeof(SelectControl)

local RadioControl = SelectOneControl(ControlType.Radio)
export.RadioControl = gt.build(RadioControl)
export type RadioControl = typeof(RadioControl)

local MultiSelectControl = SelectManyControl(ControlType.MultiSelect)
export.MultiSelectControl = gt.build(MultiSelectControl)
export type MultiSelectControl = typeof(MultiSelectControl)

local CheckControl = SelectManyControl(ControlType.Check)
export.CheckControl = gt.build(CheckControl)
export type CheckControl = typeof(CheckControl)

local PrimitiveStoryControl = gt.union(StringControl, BooleanControl, NumberControl)
export.PrimitiveStoryControl = gt.build(PrimitiveStoryControl)
export type PrimitiveStoryControl = typeof(PrimitiveStoryControl)

local AdvancedStoryControl = gt.union(SliderControl, SelectControl, MultiSelectControl, CheckControl, RadioControl)
export.AdvancedStoryControl = gt.build(AdvancedStoryControl)
export type AdvancedStoryControl = typeof(AdvancedStoryControl)

local RobloxStoryControl = gt.union(ColorControl, DateControl)
export.RobloxStoryControl = gt.build(RobloxStoryControl)
export type RobloxStoryControl = typeof(RobloxStoryControl)

local ListBasedStoryControl = gt.union(SelectControl, MultiSelectControl, CheckControl, RadioControl)
export.ListBasedStoryControl = gt.build(ListBasedStoryControl)
export type ListBasedStoryControl = typeof(ListBasedStoryControl)

local NumberBasedStoryControl = gt.union(NumberControl, SliderControl)
export.NumberBasedStoryControl = gt.build(NumberBasedStoryControl)
export type NumberBasedStoryControl = typeof(NumberBasedStoryControl)

local StoryControl = gt.union(PrimitiveStoryControl, AdvancedStoryControl, RobloxStoryControl)
export.StoryControl = gt.build(StoryControl)
export type StoryControl = typeof(StoryControl)

local StoryControlsSchema = gt.dictionary(gt.string(), gt.union(StoryControl, StoryControlValue))
export.StoryControlsSchema = gt.build(StoryControlsSchema)
export type StoryControlsSchema = typeof(StoryControlsSchema)

local StoryControls = gt.dictionary(gt.string(), StoryControlValue)
export.StoryControls = gt.build(StoryControls)
export type StoryControls = typeof(StoryControls)

return export
