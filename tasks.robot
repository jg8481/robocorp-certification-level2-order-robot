*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.
...                 Should complete all the orders even when there are technical failures with the robot order website.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.PDF
Library             RPA.FileSystem
Library             RPA.Tables
Library             RPA.HTTP
Library             RPA.Archive
Library             Dialogs
Library             RPA.Robocorp.Vault


*** Variables ***
${delay_duration}       3 seconds


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    [Setup]    Task Setup
    Get Orders CSV File
    ${csv_order_data}=    Use Orders CSV File To Gather Data
    Go To The Ordering Website
    Run The Robot Ordering Process In A Loop    ${csv_order_data}
    Gather Receipts Into A Zip File
    [Teardown]    Close Browser


*** Keywords ***
Log Lines To Console
    Log To Console    \n...\n...\n...

Task Setup
    ${testdata}=    Get Secret    testdata
    Set Suite Variable    ${testdata}
    Run Keyword And Ignore Error    Remove File    ${EXECDIR}${/}robot-spare-bin-receipts.zip
    Run Keyword And Ignore Error    Remove File    ${EXECDIR}${/}orders.csv
    Run Keyword And Ignore Error    Remove File    ${EXECDIR}${/}output${/}robot-spare-bin-receipts.zip
    Run Keyword And Ignore Error    Remove File    ${EXECDIR}${/}output${/}orders.csv
    Run Keyword And Ignore Error    Remove Directory    ${EXECDIR}${/}output${/}robot-images    True
    Run Keyword And Ignore Error    Remove Directory    ${EXECDIR}${/}output${/}receipts    True
    Create Directory    ${EXECDIR}${/}output${/}receipts
    Create Directory    ${EXECDIR}${/}output${/}robot-images

Go To The Ordering Website
    Open Available Browser    ${testdata}[website_url]/#/robot-order
    Maximize Browser Window
    Wait Until Page Contains Element    //select[@name="head"]

Get Orders CSV File
    Download    ${testdata}[website_url]/orders.csv    ${EXECDIR}${/}output${/}orders.csv
    Wait Until Keyword Succeeds    3x    ${delay_duration}    Check Orders CSV File Download

Check Orders CSV File Download
    ${csv_file_exists}=    Does File Exist    ${EXECDIR}${/}output${/}orders.csv
    IF    '${csv_file_exists}'=='True'
        Log Lines To Console
        Log To Console    The orders.csv file download was successful, this task will continue.
    ELSE
        Log Lines To Console
        Fatal Error    The orders.csv file download did not succeed, this task can not continue.
    END

Use Orders CSV File To Gather Data
    ${csv_order_data}=    Read Table From CSV    ${EXECDIR}${/}output${/}orders.csv    header=True
    Should Not Be Empty    ${csv_order_data}
    RETURN    ${csv_order_data}

Run The Robot Ordering Process In A Loop
    [Arguments]    ${csv_order_data}
    FOR    ${csv_row}    IN    @{csv_order_data}
        Run Keyword And Ignore Error    Enter Orders CSV Data Into Website Form Fields    ${csv_row}
        Run Keyword And Ignore Error    Run Checks To Recover From Errors And Continue Ordering Process
        Run Keyword And Ignore Error    Store Receipts In PDF Files    ${csv_row}
    END

Enter Orders CSV Data Into Website Form Fields
    [Arguments]    ${csv_row}
    Wait Until Page Contains Element    //button[@class="btn btn-dark"]
    Click Button    //button[@class="btn btn-dark"]
    Select From List By Value    //select[@name="head"]    ${csv_row}[Head]
    Click Element    //input[@value="${csv_row}[Body]"]
    Input Text    //input[@placeholder="Enter the part number for the legs"]    ${csv_row}[Legs]
    Input Text    //input[@placeholder="Shipping address"]    ${csv_row}[Address]
    Scroll Element Into View    //input[@placeholder="Shipping address"]
    Mouse Down    //input[@placeholder="Shipping address"]
    Sleep    ${delay_duration}
    Press Keys    //input[@placeholder="Shipping address"]    RETURN
    Press Keys    //input[@placeholder="Shipping address"]    TAB
    Wait Until Element Is Visible    //*[@id="preview"]
    Run Keyword And Ignore Error    Click Element    //*[@id="preview"]
    Run Keyword And Ignore Error    Press Keys    //*[@id="preview"]    RETURN
    Run Keyword And Ignore Error    Press Keys    //*[@id="preview"]    TAB
    Wait Until Page Contains Element    xpath=//a[contains(text(),'Robotics Vectors by Vecteezy')]
    Wait Until Page Contains Element    //div[@id="robot-preview-image"]
    Sleep    ${delay_duration}
    Run Keyword And Ignore Error    Press Keys    //button[@id="order"]    RETURN
    Sleep    ${delay_duration}
    Wait Until Page Contains Element    //button[@id="order-another"]
    Run Keyword And Continue On Failure    Page Should Contain    Receipt
    Run Keyword And Continue On Failure    Page Should Not Contain    Error
    Run Keyword And Continue On Failure    Page Should Not Contain    Errors

Run Checks To Recover From Errors And Continue Ordering Process
    WHILE    True    limit=10
        ${error_check}=    Is Element Visible    //div[@class="alert alert-danger"]
        IF    '${error_check}'=='True'
            Run Keyword And Ignore Error    Try Repeating Previous Steps And Continue Ordering Process
        ELSE
            CONTINUE
        END
    END
    IF    '${error_check}'=='True'
        Run Keyword And Ignore Error    Reset Browser And Recover From Ordering Process Errors
    END

Try Repeating Previous Steps And Continue Ordering Process
    Sleep    ${delay_duration}
    Run Keyword And Ignore Error    Scroll Element Into View    //input[@placeholder="Shipping address"]
    Run Keyword And Ignore Error    Mouse Down    //input[@placeholder="Shipping address"]
    Run Keyword And Ignore Error    Press Keys    //input[@placeholder="Shipping address"]    TAB
    Run Keyword And Ignore Error    Press Keys    //*[@id="preview"]    TAB
    Run Keyword And Ignore Error    Press Keys    //button[@id="order"]    RETURN

Reset Browser And Recover From Ordering Process Errors
    Close Browser
    Go To The Ordering Website

Store Receipts In PDF Files
    [Arguments]    ${csv_row}
    Log    The following CSV row is being used to create receipt PDF files.
    Log    ${csv_row}
    ${get_receipt}=    Get Element Attribute    //div[@id="receipt"]    outerHTML
    Html To PDF    ${get_receipt}    ${EXECDIR}${/}output${/}receipts${/}${csv_row}[Order number].pdf
    Screenshot
    ...    //div[@id="robot-preview-image"]
    ...    ${EXECDIR}${/}output${/}robot-images${/}${csv_row}[Order number].png
    Add Watermark Image To PDF
    ...    ${EXECDIR}${/}output${/}robot-images${/}${csv_row}[Order number].png
    ...    ${EXECDIR}${/}output${/}receipts${/}${csv_row}[Order number].pdf
    ...    ${EXECDIR}${/}output${/}receipts${/}${csv_row}[Order number].pdf
    Sleep    ${delay_duration}
    Click Button    //button[@id="order-another"]

Gather Receipts Into A Zip File
    Archive Folder With Zip    ${EXECDIR}${/}output${/}receipts    ${EXECDIR}${/}output${/}robot-spare-bin-receipts.zip
    Wait Until Keyword Succeeds    3x    ${delay_duration}    Check For The Receipts Zip File

Check For The Receipts Zip File
    ${check_zip_file}=    Does File Exist    ${EXECDIR}${/}output${/}robot-spare-bin-receipts.zip
    IF    ${check_zip_file}
        Log Lines To Console
        Pass Execution    The robot-spare-bin-receipts.zip file was created successfully
    ELSE
        Log Lines To Console
        Fatal Error    The robot-spare-bin-receipts.zip file was not found. This task has failed.
    END
