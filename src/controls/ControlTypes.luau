local gt = require("@pkg/GreenTea")

local ControlType = require("@root/controls/enums/ControlType")

local export = {}

export type ControlType = ControlType.ControlType

-- Make sure to update this when adding new control types!
export type StoryControlValue = boolean | number | string | Color3 | DateTime | EnumItem
local StoryControlValue: StoryControlValue = gt.union(
	-- Primitives
	gt.boolean() :: StoryControlValue,
	gt.number(),
	gt.string(),

	-- Roblox datatypes
	gt.Color3(),
	gt.isTypeof("DateTime"),
	gt.isTypeof("EnumItem")
)

local ControlOptions = gt.array(gt.string())
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

local TostringFn = gt.fn(gt.args(StoryControlValue), gt.returns(gt.string()))
local SortFn = gt.fn(gt.args(gt.args(StoryControlValue), gt.args(StoryControlValue)), gt.returns(gt.boolean()))

local SelectOneOptions = gt.struct({
	default = gt.optional(StoryControlValue),
	tostring = gt.optional(TostringFn),
	sort = gt.optional(SortFn),
})

local function SelectOneControl(controlType: ControlType)
	local control = gt.intersection(
		gt.struct({
			type = gt.literal(controlType) :: ControlType,
			items = gt.array(StoryControlValue),
		}),
		SelectOneOptions
	)

	return gt.withCustom(control, function(input: typeof(control))
		if input.default and not table.find(input.items, input.default) then
			return false, `value "{input.default}" not found in 'options'`
		end

		return true, nil
	end)
end

local SelectManyOptions = gt.struct({
	default = gt.optional(gt.array(StoryControlValue)),
	tostring = gt.optional(TostringFn),
	sort = gt.optional(SortFn),
})

local function SelectManyControl(controlType: ControlType)
	local control = gt.intersection(
		gt.struct({
			type = gt.literal(controlType) :: ControlType,
			items = gt.array(StoryControlValue),
		}),
		SelectManyOptions
	)

	return gt.withCustom(control, function(input: typeof(control))
		if input.default then
			for _, defaultOption in input.default do
				if not table.find(input.items, defaultOption) then
					return false, `value "{defaultOption}" not found in 'items'`
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

local SelectOptions = SelectOneOptions
export.SelectOptions = gt.build(SelectOptions)
export type SelectOptions = typeof(SelectOptions)

local SelectControl = SelectOneControl(ControlType.Select)
export.SelectControl = gt.build(SelectControl)
export type SelectControl = typeof(SelectControl)

local RadioOptions = SelectOneOptions
export.RadioOptions = gt.build(RadioOptions)
export type RadioOptions = typeof(RadioOptions)

local RadioControl = SelectOneControl(ControlType.Radio)
export.RadioControl = gt.build(RadioControl)
export type RadioControl = typeof(RadioControl)

local MultiSelectOptions = SelectManyOptions
export.MultiSelectOptions = gt.build(MultiSelectOptions)
export type MultiSelectOptions = typeof(MultiSelectOptions)

local MultiSelectControl = gt.intersection(SelectManyControl(ControlType.MultiSelect), MultiSelectOptions)
export.MultiSelectControl = gt.build(MultiSelectControl)
export type MultiSelectControl = typeof(MultiSelectControl)

local CheckOptions = SelectManyOptions
export.CheckOptions = gt.build(CheckOptions)
export type CheckOptions = typeof(CheckOptions)

local CheckControl = SelectManyControl(ControlType.Check)
export.CheckControl = gt.build(CheckControl)
export type CheckControl = typeof(CheckControl)

local PrimitiveStoryControl = gt.union(StringControl, BooleanControl, NumberControl)
export.PrimitiveStoryControl = gt.build(PrimitiveStoryControl)
export type PrimitiveStoryControl = typeof(PrimitiveStoryControl)

local ListBasedStoryControl = gt.union(SelectControl, MultiSelectControl, CheckControl, RadioControl)
export.ListBasedStoryControl = gt.build(ListBasedStoryControl)
export type ListBasedStoryControl = typeof(ListBasedStoryControl)

local AdvancedStoryControl = gt.union(SliderControl, ListBasedStoryControl)
export.AdvancedStoryControl = gt.build(AdvancedStoryControl)
export type AdvancedStoryControl = typeof(AdvancedStoryControl)

local RobloxStoryControl = gt.union(ColorControl, DateControl)
export.RobloxStoryControl = gt.build(RobloxStoryControl)
export type RobloxStoryControl = typeof(RobloxStoryControl)

local NumberBasedStoryControl = gt.union(NumberControl, SliderControl)
export.NumberBasedStoryControl = gt.build(NumberBasedStoryControl)
export type NumberBasedStoryControl = typeof(NumberBasedStoryControl)

local StoryControl = gt.union(PrimitiveStoryControl, AdvancedStoryControl, RobloxStoryControl)
export.StoryControl = gt.build(StoryControl)
export type StoryControl = typeof(StoryControl)

-- The Storyteller v1.5.0 migration should make it possible to remove this
-- compat type. PR here: https://github.com/flipbook-labs/storyteller/pull/84
local StoryControlValueCompat = gt.union(StoryControlValue, gt.array(StoryControlValue))
export.StoryControlValueCompat = gt.build(StoryControlValueCompat)
export type StoryControlValueCompat = typeof(StoryControlValueCompat)

local StoryControlsSchema = gt.dictionary(gt.string(), gt.union(StoryControl, StoryControlValueCompat))
export.StoryControlsSchema = gt.build(StoryControlsSchema)
export type StoryControlsSchema = typeof(StoryControlsSchema)

local StoryControls = gt.dictionary(gt.string(), StoryControlValueCompat)
export.StoryControls = gt.build(StoryControls)
export type StoryControls = typeof(StoryControls)

return export
