module Validation
    exposing
        ( ValidationResult(..)
        , andMap
        , andThen
        , fromMaybe
        , fromMaybeInitial
        , fromResult
        , fromResultInitial
        , initial
        , isInvalid
        , isValid
        , map
        , mapMessage
        , message
        , toMaybe
        , toString
        , valid
        , validate
        , withDefault
        )

{-| A data type representing the validity and error state of data, for example
user-supplied input, with functions for combining results.

There are various ways of using the tools this library provides. The recommended
way is to _store ValidationResult state in your model_, in much the same way
as you store [RemoteData] in your model.

This means your _form_ model is separate from the _underlying, validated
data_ model, and you typically need to map the form into the validated model
(see example below).

Although this may seem awkward or "too much boilerplate", particularly if
your forms have many fields, it is not surprising. Unless you can prevent
invalid input altogether, _as the user enters it_, you have to retain it
somewhere in order to render it and report back to the user what the issues
are. And the shape of the (possibly invalid) input data is _necessarily_ going
to be different from the shape of valid data.


## A simple example

Here's a simple example: a 'required' (String) input field, showing an
error message below the input field as the user types.

First, define a form model with the field to be validated wrapped in a
`ValidationResult`:

    type alias Model =
        { input : ValidationResult String }

In your view,

1.  pipe input through a validation function and into your update;
2.  set the value to either the validated or the last-entered input; and
3.  display any error message below the input element.

```
view : Model -> Html Msg
view form =
    -- ...
    div []
        [ input
            [ type_ "text"
            , value
                (form.input
                    |> Validation.toString identity
                )

            -- (2.)
            , onInput
                (Validation.validate isRequired
                    >> SetInput
                )

            -- (1.)
            ]
            []
        , div
            [ class "error" ]
            [ text
                (Validation.message form.input
                    |> Maybe.withDefault ""
                )

            -- (3.)
            ]
        ]
```

(Note: often you will want an `onBlur` event as well, but this is left as an
exercise for the reader.)

Your validation functions are defined as `a -> Result String a`:

    isRequired : String -> Result String String
    isRequired raw =
        if String.length raw < 1 then
            Err "Required"
        else
            Ok raw


## Combining validation results

Typically, you want to combine validation results of several fields, such that
if _all_ of the fields are valid, then their values are extracted and the
underlying model is updated, perhaps via a remote http call.

This library provides `andMap`, which allows you to do this (assuming your
form model is `Form`, and your underlying validated model is `Model`):

    validateForm : Form -> ValidationResult Model
    validateForm form =
        Validation.valid Model
            |> Validation.andMap form.field1
            |> Validation.andMap form.field2


    --...

Using such a function, you can `Validation.map` the result into encoded form
and package it into an http call, etc.

Note that this library does not currently support accumulating validation errors
(e.g. multiple validations). The error message type is fixed as `String`. So
the `andMap` example above is not intended to give you a list of errors in the
`Invalid` case. Instead, it simply returns the first `Initial` or `Invalid` of the
applied `ValidationResult`s.

[RemoteData]: http://package.elm-lang.org/packages/krisajenkins/remotedata/latest


## Basics

@docs ValidationResult
@docs validate
@docs valid
@docs initial
@docs map
@docs andThen
@docs andMap
@docs mapMessage


## Extracting

@docs withDefault
@docs message
@docs isValid
@docs isInvalid


## Converting

@docs fromMaybeInitial
@docs fromMaybe
@docs toMaybe
@docs fromResultInitial
@docs fromResult
@docs toString

-}


{-| A wrapped value has three states:

  - `Initial` - No input yet.
  - `Valid` - Input is valid, and here is the valid (parsed) data.
  - `Invalid` - Input is invalid, and here is the error message and your last input.

-}
type ValidationResult val
    = Initial
    | Valid val
    | Invalid String String


{-| Map a function into the `Valid` value.
-}
map : (a -> b) -> ValidationResult a -> ValidationResult b
map fn validation =
    case validation of
        Initial ->
            Initial

        Valid val ->
            Valid (fn val)

        Invalid msg input ->
            Invalid msg input


{-| Map over the error message value, producing a new ValidationResult
-}
mapMessage : (String -> String) -> ValidationResult val -> ValidationResult val
mapMessage fn validation =
    case validation of
        Invalid msg input ->
            Invalid (fn msg) input

        _ ->
            validation


{-| Chain a function returning ValidationResult onto a ValidationResult
-}
andThen : (a -> ValidationResult b) -> ValidationResult a -> ValidationResult b
andThen fn validation =
    case validation of
        Initial ->
            Initial

        Valid val ->
            fn val

        Invalid msg input ->
            Invalid msg input


{-| Put the results of two ValidationResults together.

Useful for merging field ValidationResults into a single 'form'
ValidationResult. See the example above.

-}
andMap : ValidationResult a -> ValidationResult (a -> b) -> ValidationResult b
andMap validation validationFn =
    case validationFn of
        Initial ->
            Initial

        Valid fn ->
            map fn validation

        Invalid msg input ->
            Invalid msg input


{-| Put a valid value into a ValidationResult.
-}
valid : val -> ValidationResult val
valid =
    Valid


{-| Initialize a ValidationResult to the empty case (no input).
-}
initial : ValidationResult val
initial =
    Initial


{-| Extract the `Valid` value, or the given default
-}
withDefault : val -> ValidationResult val -> val
withDefault default validation =
    case validation of
        Valid val ->
            val

        _ ->
            default


{-| Convert a `Maybe` into either `Initial` (if `Nothing`) or `Valid` (if `Just`)
-}
fromMaybeInitial : Maybe val -> ValidationResult val
fromMaybeInitial maybe =
    case maybe of
        Nothing ->
            Initial

        Just val ->
            Valid val


{-| Convert a `Maybe` into either `Invalid`, with given message and input, or `Valid`.
-}
fromMaybe : String -> String -> Maybe val -> ValidationResult val
fromMaybe msg input maybe =
    case maybe of
        Nothing ->
            Invalid msg input

        Just val ->
            Valid val


{-| Convert a `ValidationResult` to a `Maybe`. Note `Invalid` state is dropped.
-}
toMaybe : ValidationResult val -> Maybe val
toMaybe validation =
    case validation of
        Valid val ->
            Just val

        _ ->
            Nothing


{-| Convert a `Result` into either `Initial` (if `Err`) or `Valid` (if `Ok`).
Note `Err` state is dropped.
-}
fromResultInitial : Result msg val -> ValidationResult val
fromResultInitial result =
    case result of
        Ok val ->
            Valid val

        Err _ ->
            Initial


{-| Convert a `Result` into either `Invalid`, using given function mapping the `Err`
value to the error message (`String`), and the given input string; or `Valid`.

Note: this function may be useful for unusual scenarios where you have a
Result already and you need to convert it. More typically you would pass
a Result-returning function to `validate` &mdash; which calls `fromResult`
internally.

-}
fromResult : (msg -> String) -> String -> Result msg val -> ValidationResult val
fromResult fn input result =
    case result of
        Ok val ->
            Valid val

        Err msg ->
            Invalid (fn msg) input


{-| Convert the ValidationResult to a String representation:

  - if Valid, convert the value to a string with the given function;
  - if Invalid, return the input (unvalidated) string;
  - if Initial, return the empty string ("").

Note: this is mainly useful as a convenience function for setting the `value`
attribute of an `Html.input` element.

-}
toString : (val -> String) -> ValidationResult val -> String
toString fn validation =
    case validation of
        Initial ->
            ""

        Valid val ->
            fn val

        Invalid _ input ->
            input


{-| Extract the error message of an `Invalid`, or Nothing
-}
message : ValidationResult val -> Maybe String
message validation =
    case validation of
        Invalid msg _ ->
            Just msg

        _ ->
            Nothing


{-| Return True if and only if `Valid`. Note `Initial` -> `False`
(`Initial` is not valid).
-}
isValid : ValidationResult val -> Bool
isValid validation =
    case validation of
        Valid _ ->
            True

        _ ->
            False


{-| Return True if and only if `Invalid`. Note `Initial` -> `False`
(`Initial` is not invalid).
-}
isInvalid : ValidationResult val -> Bool
isInvalid validation =
    case validation of
        Invalid _ _ ->
            True

        _ ->
            False


{-| Run a validation function on an input string, to create a ValidationResult.

Note the validation function you provide is `String -> Result String a`, where
`a` is the type of the valid value.

So a validation function for "integer less than 10" looks like:

    lessThanTen : String -> Result String Int
    lessThanTen input =
        String.toInt input
            |> Result.andThen
                (\i ->
                    if i < 10 then
                        Ok i
                    else
                        Err "Must be less than 10"
                )

-}
validate : (String -> Result String val) -> String -> ValidationResult val
validate fn input =
    case fn input of
        Err msg ->
            Invalid msg input

        Ok val ->
            Valid val
