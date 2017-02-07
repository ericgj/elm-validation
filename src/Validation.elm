module Validation 
  exposing 
    ( ValidationResult(..)
    , map, mapMessage, andThen, andMap, valid, initial
    , withDefault
    , fromMaybeInitial, fromMaybe, toMaybe
    , fromResultInitial, fromResult
    , toString, message, isValid, isInvalid
    , validate
    )

{-| 
 
A data type representing the validity and error state of data, for example 
user-supplied input, with functions for combining results.

There are various ways of using the tools this library provides. The recommended
way is to _store ValidationResult state in your model_, in much the same way
as you store [RemoteData][] in your model. 

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

``` elm
type alias Model = 
    { input : ValidationResult String }
```

In your view, 
  
  1. pipe input through a validation function and into your update;
  2. set the value to either the validated or the last-entered input; and
  3. display any error message below the input element.

```
view : Model -> Html Msg
view form =
    -- ...
    div []
      [ input 
          [ type_ "text"
          , value form.input |> Validation.toString identity        -- (1.)
          , onInput (Validation.validate isRequired >> SetInput)    -- (2.)
          ] []
      , div 
          [ class "error" ]
          [ text (Validation.message form.input |> Maybe.withDefault "") -- (3.)
          ]
      ]
```
(Note: often you will want an `onBlur` event as well, but this is left as an
exercise for the reader.)

Your validation functions are defined as `a -> Result String a`:

``` elm
isRequired : String -> Result String String
isRequired raw =
  if String.length < 1 then
    Err "Required"
  else
    Ok raw
```

## Combining validation results

Typically, you want to combine validation results of several fields, such that
if _all_ of the fields are valid, then their values are extracted and the
underlying model is updated, perhaps via a remote http call.

This library provides `andMap`, which allows you to do this (assuming your
form model is `Form`, and your underlying validated model is `Model`):

```elm
validateForm : Form -> ValidationResult Model
validateForm form =
    Validation.valid Model
      |> Validation.andMap form.field1
      |> Validation.andMap form.field2
      --...    
```

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
  - `Valid`   - Input is valid, and here is the valid (parsed) data.
  - `Invalid` - Input is invalid, and here is the error message and your last input.
-}
type ValidationResult a
  = Initial 
  | Valid a
  | Invalid String String

{-| Map a function into the `Valid` value.
-}
map : (a -> b) -> ValidationResult a -> ValidationResult b
map fn r =
  case r of
    Initial -> Initial
    Invalid msg input -> Invalid msg input
    Valid a -> Valid (fn a)

{-| Map over the error message value, producing a new ValidationResult
-}
mapMessage : (String -> String) -> ValidationResult a -> ValidationResult a
mapMessage fn r =
  case r of
    Initial -> Initial
    Valid a -> Valid a
    Invalid msg input -> Invalid (fn msg) input

{-| Chain a function returning ValidationResult onto a ValidationResult
-}
andThen : (a -> ValidationResult b) -> ValidationResult a -> ValidationResult b
andThen fn r =
  case r of
    Initial -> Initial
    Invalid msg input -> Invalid msg input
    Valid a -> fn a


{-| 
Put the results of two ValidationResults together. 

Useful for merging field ValidationResults into a single 'form' 
ValidationResult. See the example above.
-}
andMap : ValidationResult a -> ValidationResult (a -> b) -> ValidationResult b
andMap r fn = 
  case r of
    Initial -> Initial
    Invalid msg input -> Invalid msg input
    Valid a -> r |> andThen (\r_ -> fn |> andThen (\f_ -> Valid (f_ r_)))


{-| Put a valid value into a ValidationResult.
-}
valid : a -> ValidationResult a
valid a = 
    Valid a


{-| Initialize a ValidationResult to the empty case (no input).
-}
initial : ValidationResult a
initial = Initial


{-| Extract the `Valid` value, or the given default
-}
withDefault : a -> ValidationResult a -> a
withDefault a r =
  case r of
    Initial -> a
    Invalid msg input -> a
    Valid a_ -> a_


{-| Convert a `Maybe` into either `Initial` (if `Nothing`) or `Valid` (if `Just`)
-}
fromMaybeInitial : Maybe a -> ValidationResult a
fromMaybeInitial m =
  case m of
    Nothing -> Initial
    Just a -> Valid a


{-| Convert a `Maybe` into either `Invalid`, with given message and input, or `Valid`.
-}
fromMaybe : String -> String -> Maybe a -> ValidationResult a
fromMaybe msg input m =
  case m of
    Nothing -> Invalid msg input
    Just a -> Valid a


{-| Convert a `ValidationResult` to a `Maybe`. Note `Invalid` state is dropped.
-}
toMaybe : ValidationResult a -> Maybe a
toMaybe r =
  case r of
    Initial -> Nothing
    Invalid msg input -> Nothing
    Valid a -> Just a


{-| Convert a `Result` into either `Initial` (if `Err`) or `Valid` (if `Ok`).
    Note `Err` state is dropped.
-}
fromResultInitial : Result e a -> ValidationResult a
fromResultInitial m =
  case m of
    Ok a -> Valid a
    Err e -> Initial


{-| 
Convert a `Result` into either `Invalid`, using given function mapping the `Err`
value to the error message (`String`), and the given input string; or `Valid`.

Note: this function may be useful for unusual scenarios where you have a
Result already and you need to convert it. More typically you would pass
a Result-returning function to `validate` &mdash; which calls `fromResult`
internally.
-}
fromResult : (e -> String) -> String -> Result e a -> ValidationResult a
fromResult fn input m =
  case m of
    Ok a -> Valid a
    Err e -> Invalid (fn e) input


{-| 
Convert the ValidationResult to a String representation:

  - if Valid, convert the value to a string with the given function;
  - if Invalid, return the input (unvalidated) string;
  - if Initial, return the empty string ("").
    
Note: this is mainly useful as a convenience function for setting the `value`
attribute of an `Html.input` element.
-}
toString : (a -> String) -> ValidationResult a -> String 
toString fn r =
  case r of
    Valid a -> fn a
    Invalid _ last -> last
    Initial -> ""


{-|  Extract the error message of an `Invalid`, or Nothing
-}
message : ValidationResult a -> Maybe String
message r =
  case r of
    Initial -> Nothing
    Valid _ -> Nothing
    Invalid msg _ -> Just msg


{-| 
Return True if and only if `Valid`. Note `Initial` -> `False`
(`Initial` is not valid).
-}
isValid : ValidationResult a -> Bool
isValid r =
  case r of
    Valid _ -> True
    _ -> False


{-| 
Return True if and only if `Invalid`. Note `Initial` -> `False` 
(`Initial` is not invalid).
-}
isInvalid : ValidationResult a -> Bool
isInvalid r =
  case r of
    Initial -> False
    Valid _ -> False
    Invalid msg last -> True 


{-| 
Run a validation function on an input string, to create a ValidationResult.

Note the validation function you provide is `String -> Result String a`, where
`a` is the type of the valid value.

So a validation function for "integer less than 10" looks like:

``` elm
lessThanTen : String -> Result String Int
lessThanTen input =
    String.toInt input
        |> Result.andThen 
            (\i -> if i < 10 then (Ok i) else (Err "Must be less than 10"))
```
-}
validate : (String -> Result String a) -> String -> ValidationResult a
validate fn input =
  fn input |> fromResult identity input


