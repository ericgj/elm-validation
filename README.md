# elm-validation

Tools for managing validity and error state of data, e.g. from user input.

## To install

```
$ elm install ericgj/elm-validation
```

## Example

Basic usage for validation in an HTML form.

    view : Form -> Html Msg
    view form =
        div []
            [ input
                [ type_ "text"
                , value
                    (form.input
                        |> Validation.toString identity
                    )
                , onInput
                    (Validation.validate isRequired
                        >> SetInput
                    )
                ]
                []
            , div 
                [ class "error" ]
                [ text
                    (Validation.message form.input
                        |> Maybe.withDefault ""
                    )
                ]
            ]


Combining validation of form fields to determine overall validity of a model.
(For example, this could be used to determine if the submit button should be
enabled on the form.)

    validateForm : Form -> ValidationResult Model
    validateForm form =
        Validation.valid Model
            |> Validation.andMap form.field1
            |> Validation.andMap form.field2



[See the Elm package for full usage docs][pkg].



[pkg]: http://package.elm-lang.org/packages/ericgj/elm-validation/latest

