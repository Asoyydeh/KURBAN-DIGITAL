// TEMPLATE GOOGLE APPS SCRIPT UNTUK KURBAN DIGITAL
// Silakan copy seluruh kode ini dan paste di editor Google Apps Script Anda.

const SHEET_NAME_ANIMALS = "Animals";
const SHEET_NAME_SHOHIBULS = "Shohibuls";
const SHEET_NAME_RECIPIENTS = "Recipients";
const SHEET_NAME_PAYMENTS = "Payments";

// Fungsi untuk setup Spreadsheet awal (Jalankan sekali secara manual di editor)
function setup() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // Create sheets if not exist
  const sheets = [SHEET_NAME_ANIMALS, SHEET_NAME_SHOHIBULS, SHEET_NAME_RECIPIENTS, SHEET_NAME_PAYMENTS];
  sheets.forEach(name => {
    if (!ss.getSheetByName(name)) {
      ss.insertSheet(name);
    }
  });

  // Setup Headers (Force overwrite row 1 to keep them always synchronized and correct)
  ss.getSheetByName(SHEET_NAME_ANIMALS).getRange(1, 1, 1, 6).setValues([["id", "type", "weight", "age", "health", "status"]]);
  ss.getSheetByName(SHEET_NAME_SHOHIBULS).getRange(1, 1, 1, 6).setValues([["name", "phone", "package", "type", "price", "status"]]);
  ss.getSheetByName(SHEET_NAME_RECIPIENTS).getRange(1, 1, 1, 9).setValues([["code", "name", "familyCount", "block", "housing", "color", "meatType", "status", "phone"]]);
  ss.getSheetByName(SHEET_NAME_PAYMENTS).getRange(1, 1, 1, 4).setValues([["sender", "amount", "method", "status"]]);
}

// Handler HTTP GET (Untuk mengambil data dari Spreadsheet ke Web)
function doGet(e) {
  const data = {
    animals: getSheetData(SHEET_NAME_ANIMALS),
    shohibuls: getSheetData(SHEET_NAME_SHOHIBULS),
    recipients: getSheetData(SHEET_NAME_RECIPIENTS),
    payments: getSheetData(SHEET_NAME_PAYMENTS)
  };
  
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// Handler HTTP POST (Untuk menyimpan/sinkronisasi data dari Web ke Spreadsheet)
function doPost(e) {
  try {
    const postData = JSON.parse(e.postData.contents);
    const action = postData.action;
    
    if (action === "syncData") {
      updateSheetData(SHEET_NAME_ANIMALS, postData.data.animals, ["id", "type", "weight", "age", "health", "status"]);
      updateSheetData(SHEET_NAME_SHOHIBULS, postData.data.shohibuls, ["name", "phone", "package", "type", "price", "status"]);
      updateSheetData(SHEET_NAME_RECIPIENTS, postData.data.recipients, ["code", "name", "familyCount", "block", "housing", "color", "meatType", "status", "phone"]);
      updateSheetData(SHEET_NAME_PAYMENTS, postData.data.payments, ["sender", "amount", "method", "status"]);
      
      return ContentService.createTextOutput(JSON.stringify({ status: "success", message: "Data tersimpan ke Spreadsheet!" }))
        .setMimeType(ContentService.MimeType.JSON);
    }
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function getSheetData(sheetName) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet) return [];
  
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];
  
  const headers = data[0];
  const rows = data.slice(1);
  
  return rows.map(row => {
    let obj = {};
    headers.forEach((header, index) => {
      obj[header] = row[index];
    });
    return obj;
  });
}

function updateSheetData(sheetName, dataArray, headers) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet) return;
  
  // Force write/overwrite headers in Row 1 to keep them always synchronized
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  
  const lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    sheet.getRange(2, 1, lastRow - 1, sheet.getLastColumn()).clearContent();
  }
  
  if (!dataArray || dataArray.length === 0) return;
  
  const insertData = dataArray.map(item => {
    return headers.map(header => item[header] || "");
  });
  
  sheet.getRange(2, 1, insertData.length, headers.length).setValues(insertData);
}
