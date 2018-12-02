module Validation exposing
    ( ValidationResult(..)
    , validate
    , valid
    , initial
    , unvalidated
    , map
    , andThen
    , andMap
    , mapMessage
    , withDefault
    , message
    , isValid
    , isInvalid
    , fromMaybe
    , fromMaybeInitial
    , fromMaybeUnvalidated
    , toMaybe
    , fromResult
    , fromResultInitial
    , fromResultUnvalidated
    , toString
    )

{-| A data type representing the validity and error state of data, for example
user-supplied input, with functions for combining results.

There are various ways of using the tools this library provides. The recommended
way is to _store ValidationResult state in your model_, in much the same way
as you store [RemoteData] in your model.

This means your _form_ model is separate from the _validated data_ model,
and you typically need to map the form into the validated model (see example
below).


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

    view : Model -> Html Msg
    view form =
    -- ...
    div []
    [ input
    [ type\_ "text"

                --------------------------- (2.)
                , value
                    (form.input
                        |> Validation.toString identity
                    )

                --------------------------- (1.)
                , onInput
                    (Validation.validate isRequired
                        >> SetInput
                    )
                ]
                []
            , div
                [ class "error" ]
                --------------------------- (3.)
                [ text
                    (Validation.message form.input
                        |> Maybe.withDefault ""
                    )
                ]
            ]

Your validation functions are defined as `a -> Result String a`:

    isRequired : String -> Result String String
    isRequired raw =
        if String.length raw < 1 then
            Err "Required"

        else
            Ok raw

Often you will want to validate input when the input loses focus (`onBlur`),
instead of immediately (`onInput`). `ValidationResult` supports this with the
`Unvalidated` state, which allows you to store input before validation (see
below, and [full example here][on-blur-example]).

Also note if you do validate `onInput` as above, in most cases you should _also_
validate `onBlur` if the field is required.


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

Using such a function, you can `Validation.map` the result into encoded form
and package it into an http call, etc.

Note that this library does not currently support accumulating validation errors
(e.g. multiple validations). The error message type is fixed as `String`. So
the `andMap` example above is not intended to give you a list of errors in the
`Invalid` case. Instead, it simply returns the first `Initial` or `Invalid` of
the applied `ValidationResult`s.

For an approach that does accumulate validation errors, see [elm-verify].

[RemoteData]: http://package.elm-lang.org/packages/krisajenkins/remotedata/latest

[elm-verify]: http://package.elm-lang.org/packages/stoeffel/elm-verify/latest

[on-blur-example]: https://github.com/ericgj/elm-validation/blob/master/example/OnBlur.elm


## Basics

@docs ValidationResult
@docs validate
@docs valid
@docs initial
@docs unvalidated
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

@docs fromMaybe
@docs fromMaybeInitial
@docs fromMaybeUnvalidated
@docs toMaybe
@docs fromResult
@docs fromResultInitial
@docs fromResultUnvalidated
@docs toString

-}


{-| A wrapped value has four states:

  - `Initial` - No input yet.
  - `Unvalidated` - Input received but not yet validated, and here it is.
  - `Valid` - Input is valid, and here is the valid (parsed) data.
  - `Invalid` - Input is invalid, and here is the error message and your last input.

-}
type ValidationResult value
    = Initial
    | Unvalidated String
    | Valid value
    | Invalid String String


{-| Map a function into the `Valid` value.
-}
map : (a -> b) -> ValidationResult a -> ValidationResult b
map fn validation =
    case validation of
        Initial ->
            Initial

        Unvalidated input ->
            Unvalidated input

        Valid value ->
            Valid (fn value)

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

        Unvalidated input ->
            Unvalidated input

        Valid value ->
            fn value

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

        Unvalidated input ->
            Unvalidated input

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


{-| Initialize a ValidationResult to unvalidated input.
-}
unvalidated : String -> ValidationResult val
unvalidated =
    Unvalidated


{-| Extract the `Valid` value, or the given default
-}
withDefault : val -> ValidationResult val -> val
withDefault default validation =
    case validation of
        Valid value ->
            value

        _ ->
            default


{-| Convert a `Maybe` into either `Initial` (if `Nothing`) or `Valid` (if `Just`)
-}
fromMaybeInitial : Maybe val -> ValidationResult val
fromMaybeInitial maybe =
    case maybe of
        Nothing ->
            Initial

        Just value ->
            Valid value


{-| Convert a `Maybe` into either `Unvalidated`, with given input, or `Valid`.
-}
fromMaybeUnvalidated : String -> Maybe val -> ValidationResult val
fromMaybeUnvalidated input maybe =
    case maybe of
        Nothing ->
            Unvalidated input

        Just value ->
            Valid value


{-| Convert a `Maybe` into either `Invalid`, with given message and input, or `Valid`.
-}
fromMaybe : String -> String -> Maybe val -> ValidationResult val
fromMaybe msg input maybe =
    case maybe of
        Nothing ->
            Invalid msg input

        Just value ->
            Valid value


{-| Convert a `ValidationResult` to a `Maybe`. Note `Invalid` and `Unvalidated` state is dropped.
-}
toMaybe : ValidationResult val -> Maybe val
toMaybe validation =
    case validation of
        Valid value ->
            Just value

        _ ->
            Nothing


{-| Convert a `Result` into either `Initial` (if `Err`) or `Valid` (if `Ok`).
Note `Err` state is dropped.
-}
fromResultInitial : Result msg val -> ValidationResult val
fromResultInitial result =
    case result of
        Ok value ->
            Valid value

        Err _ ->
            Initial


{-| Convert a `Result` into either `Unvalidated` (if `Err`) or `Valid` (if `Ok`).
-}
fromResultUnvalidated : (msg -> String) -> Result msg val -> ValidationResult val
fromResultUnvalidated fn result =
    case result of
        Ok value ->
            Valid value

        Err msg ->
            Unvalidated (fn msg)


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
        Ok value ->
            Valid value

        Err msg ->
            Invalid (fn msg) input


{-| Convert the ValidationResult to a String representation:

  - if Valid, convert the value to a string with the given function;
  - if Unvalidated, return the input (unvalidated) string;
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

        Unvalidated input ->
            input

        Valid value ->
            fn value

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


{-| Return True if and only if `Valid`. Note `Initial` and `Unvalidated`
results are False.
-}
isValid : ValidationResult val -> Bool
isValid validation =
    case validation of
        Valid _ ->
            True

        _ ->
            False


{-| Return True if and only if `Invalid`. Note `Initial` and `Unvalidated`
results are False.
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

        Ok value ->
            Valid value
