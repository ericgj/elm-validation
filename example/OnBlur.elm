module OnBlur exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, targetValue)
import Json.Decode as Json
import Validation exposing (ValidationResult)


main : Program () Form Msg
main =
    Browser.sandbox
        { init = init
        , view = view
        , update = update
        }


type alias Model =
    { name : String
    , birthdate : Date
    , tickets : Int
    }


type alias Form =
    { name : ValidationResult String
    , birthdate : ValidationResult Date
    , tickets : ValidationResult Int
    }


type Date
    = Date { year : Int, month : Int, day : Int }


init : Form
init =
    { name = Validation.Initial
    , birthdate = Validation.Initial
    , tickets = Validation.Initial
    }


ymd : Int -> Int -> Int -> Date
ymd year month day =
    Date { year = year, month = month, day = day }


type Msg
    = SetName (ValidationResult String)
    | SetBirthdate (ValidationResult Date)
    | SetTickets (ValidationResult Int)
    | Submit Model


update : Msg -> Form -> Form
update msg form =
    case msg of
        SetName result ->
            { form | name = result }

        SetBirthdate result ->
            { form | birthdate = result }

        SetTickets result ->
            { form | tickets = result }

        Submit model ->
            let
                _ =
                    Debug.log "Success!" model
            in
            form


view : Form -> Html Msg
view form =
    let
        nameValid =
            Validation.validate isRequired

        birthdateValid =
            Validation.validate isValidBirthdate

        ticketsValid =
            Validation.validate
                (isValidTickets <| Validation.toMaybe form.birthdate)

        formState =
            Validation.valid Model
                |> Validation.andMap form.name
                |> Validation.andMap form.birthdate
                |> Validation.andMap form.tickets
    in
    div [ class "form" ]
        [ div [ class "form__field" ]
            [ label [ for "name" ] [ text "Name" ]
            , input
                ([ type_ "text"
                 , name "name"
                 , onInput (Validation.unvalidated >> SetName)
                 , onBlur (nameValid >> SetName)
                 ]
                    ++ validInputStyle form.name
                )
                []
            , div [ class "form__error" ]
                [ text
                    (Validation.message form.name
                        |> Maybe.withDefault ""
                    )
                ]
            ]
        , div [ class "form__field" ]
            [ label [ for "birthdate" ] [ text "Date of birth" ]
            , input
                ([ type_ "date"
                 , name "birthdate"
                 , onInput (Validation.unvalidated >> SetBirthdate)
                 , onBlur (birthdateValid >> SetBirthdate)
                 ]
                    ++ validInputStyle form.birthdate
                )
                []
            , div [ class "form__error" ]
                [ text
                    (Validation.message form.birthdate
                        |> Maybe.withDefault ""
                    )
                ]
            ]
        , div [ class "form__field" ]
            [ label [ for "tickets" ] [ text "# Tickets" ]
            , input
                ([ type_ "number"
                 , name "tickets"
                 , Html.Attributes.min "1"
                 , Html.Attributes.max "99"
                 , Html.Attributes.step "1"
                 , disabled (not <| Validation.isValid form.birthdate)
                 , onInput (ticketsValid >> SetTickets)
                 , onBlur (ticketsValid >> SetTickets)
                 ]
                    ++ validInputStyle form.tickets
                )
                []
            , div [ class "form__error" ]
                [ text
                    (Validation.message form.tickets
                        |> Maybe.withDefault ""
                    )
                ]
            ]
        , div [ class "form__submit" ]
            (case formState of
                Validation.Valid model ->
                    [ button [ onClick (Submit model) ] [ text "Save" ]
                    ]

                _ ->
                    []
            )
        ]


validInputStyle : ValidationResult x -> List (Attribute msg)
validInputStyle result =
    if Validation.isInvalid result then
        [ style "background-color" "pink" ]

    else
        []


isRequired : String -> Result String String
isRequired raw =
    if String.length raw < 1 then
        Err "Required"

    else
        Ok raw


isValidBirthdate : String -> Result String Date
isValidBirthdate raw =
    isValidDate raw
        |> Result.andThen isValidBirthdateHelp



{- Note: obviously in a real app you would not hard-code the year! -}


isValidBirthdateHelp : Date -> Result String Date
isValidBirthdateHelp ((Date { year, month, day }) as date) =
    if (2017 - year) >= 100 || (year >= 2017) then
        Err "Check the year"

    else if (2017 - year) >= 12 then
        Ok date

    else
        Err "Sorry, you have to be at least 12 years old to ride"


isValidDate : String -> Result String Date
isValidDate raw =
    let
        validParts parts =
            case parts of
                year :: month :: day :: [] ->
                    Result.map3 ymd
                        (stringToIntResult year)
                        (stringToIntResult month)
                        (stringToIntResult day)

                _ ->
                    Err "Invalid date format"
    in
    raw
        |> isRequired
        |> Result.map (String.split "-")
        |> Result.andThen validParts


isValidTickets : Maybe Date -> String -> Result String Int
isValidTickets birthdate raw =
    case birthdate of
        Nothing ->
            Err "Please enter your date of birth first"

        Just date ->
            raw
                |> isRequired
                |> Result.andThen stringToIntResult
                |> Result.andThen (isValidTicketsHelp date)



{- Note numeric input min, max, etc. don't prevent the user from manually
   entering a number outside the range, so we double-check for this here.
-}


isValidTicketsHelp : Date -> Int -> Result String Int
isValidTicketsHelp (Date { year }) tickets =
    if tickets < 1 then
        Err "You have to order at least one ticket"

    else if tickets > 99 then
        Err "You ordered too many tickets"

    else if (2017 - year) < 20 && (tickets > 1) then
        Err "You have to be at least 20 years old to buy more than one ticket"

    else
        Ok tickets


stringToIntResult : String -> Result String Int
stringToIntResult =
    String.toInt >> Result.fromMaybe "Not a number"


onBlur : (String -> msg) -> Html.Attribute msg
onBlur tagger =
    on "blur" (Json.map tagger targetValue)
