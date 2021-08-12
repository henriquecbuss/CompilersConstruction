{- UFSC - CTC - INE5426 Construcao de Compiladores
   Henrique da Cunha Buss
   June 2021
-}


port module Main exposing (main)

{-| The main module is responsible for parsing command-line arguments,
requesting data from JS, and showing the output of our program
-}

import CCParser
import Json.Decode as Decode
import Json.Encode as Encode
import Parser.Advanced as Parser
import Parser.Program as Program
import Syntax.Program
import Syntax.Symbol



-- PORTS


port requestFile : String -> Cmd msg


port getFile : (Encode.Value -> msg) -> Sub msg


port print : String -> Cmd msg


port printTable : Encode.Value -> Cmd msg



-- MAIN


main : Program Encode.Value Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { program : Maybe Syntax.Program.Program }


init : Encode.Value -> ( Model, Cmd Msg )
init flags =
    let
        filename =
            case Decode.decodeValue (Decode.list Decode.string) flags of
                Ok [ x ] ->
                    Ok x

                Ok [] ->
                    Err "I received no file names! Please give me exactly one file name!"

                Ok _ ->
                    Err "I received too many arguments! I only accept a single file name!"

                Err _ ->
                    Err "I couldn't decode the CLI arguments, make sure you're sending them in correctly!"
    in
    ( { program = Nothing }
    , case filename of
        Ok file ->
            requestFile file

        Err err ->
            print err
    )



-- MSG


type Msg
    = GotFile (Result Decode.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update (GotFile fileResult) model =
    case fileResult of
        Err err ->
            ( model
            , Decode.errorToString err
                |> print
            )

        Ok fileContent ->
            case Parser.run Program.program fileContent of
                Ok validProgram ->
                    ( { model | program = Just validProgram }
                    , Cmd.batch
                        [ Syntax.Program.show validProgram
                            |> print
                        , Syntax.Symbol.tableFromProgram validProgram
                            |> Syntax.Symbol.encodeTable
                            |> printTable
                        ]
                    )

                Err err ->
                    ( model
                    , CCParser.deadEndsToString err
                        |> print
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    getFile (Decode.decodeValue getFileDecoder >> GotFile)



-- HELPERS


getFileDecoder : Decode.Decoder String
getFileDecoder =
    Decode.field "fileContents" Decode.string
