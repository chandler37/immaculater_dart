## 0.6.0

        - UnauthenticatedException is a new subclass of ApiException for
        HTTP 403 responses (which confuse authorization with
        authentication (see HTTP 401) but really are about
        authentication).

## 0.5.0

        - Protobufs now feature a message UserInfoAndToDoList.

## 0.4.0

        - JSON Web Token (JWT) authentication is supported.

## 0.3.0

        - Merely updates the protocol with two new booleans for
        MergeToDoListRequest.

## 0.2.0

        - Downgrades meta dependency to play nice with Flutter. Many
        incremental improvements and new APIs. Many new tests.

## 0.1.0

        - Initial version (thank you to the Stagehand code generator),
        shaped with care to perhaps work for a 'we never need to merge'
        use case. Perhaps even when a merge is required.
